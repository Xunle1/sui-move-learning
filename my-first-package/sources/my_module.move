module my_first_package::my_module {

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Sword has key, store {
        id: UID,
        magic: u64,
        strength: u64,
    }

    struct Forge has key, store {
        id: UID,
        swords_created: u64,
    }

    fun init(ctx: &mut TxContext) {
        let admin = Forge {
            id: object::new(ctx),
            swords_created: 0,
        };

        transfer::transfer(admin, tx_context::sender(ctx));
    }

    public fun magic(self: &Sword): u64 {
        self.magic
    }

    public fun strength(self: &Sword): u64 {
        self.strength
    }

    public fun swords_created(self: &Forge): u64 {
        self.swords_created
    }

    public fun new_sword(forge: &mut Forge, magic: u64, strength: u64, ctx: &mut TxContext): Sword {
        forge.swords_created = forge.swords_created + 1;
        Sword {
            id: object::new(ctx),
            magic: magic,
            strength: strength,
        }
    }

    #[test_only] use sui::test_scenario as ts;

    #[test_only] const ADMIN: address = @0xAD;

    #[test]
    public fun test_module_init() {
        let ts = ts::begin(@0x0);

        {
            ts::next_tx(&mut ts, ADMIN);
            init(ts::ctx(&mut ts));
        };
        {
            ts::next_tx(&mut ts, ADMIN);
            let forge: Forge = ts::take_from_sender(&ts);
            assert!(swords_created(&forge) == 0, 1);
            ts::return_to_sender(&ts, forge);
        };

        ts::end(ts);
    }

    public entry fun sword_create(magic: u64, strength: u64, recipient: address, ctx: &mut TxContext) {
        let sword = Sword {
            id: object::new(ctx),
            magic: magic,
            strength: strength,
        };
        transfer::transfer(sword, recipient);
    }

    #[test]
    public fun test_sword_create() {
        let ctx = tx_context::dummy();

        let sword = Sword {
            id: object::new(&mut ctx),
            magic: 42,
            strength: 7,
        };

        assert!(magic(&sword) == 42 && strength(&sword) == 7, 1);
        let dummy_address = @0xCAFE;
        transfer::transfer(sword, dummy_address);
    }

    public entry fun sword_transfer(sword: Sword, recipient: address, _ctx: &mut TxContext) {
        transfer::transfer(sword, recipient);
    }

    #[test]
    fun test_sword_transactions() {
        use sui::test_scenario;

        let admin = @0xBABE;
        let initial_owner = @0xCAFE;
        let final_owner = @0xFACE;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, admin);
        {
            sword_create(42, 7, initial_owner, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, initial_owner);
        {
            let sword = test_scenario::take_from_sender<Sword>(scenario);
            sword_transfer(sword, final_owner, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, final_owner);
        {
            let sword = test_scenario::take_from_sender<Sword>(scenario);
            assert!(magic(&sword) == 42 && strength(&sword) == 7, 1);
            test_scenario::return_to_sender(scenario, sword);
        };
        test_scenario::end(scenario_val);
    }
}