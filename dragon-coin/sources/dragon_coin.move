module example::dragon {
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use std::option;

    struct DRAGON has drop {}

    fun init(witness: DRAGON, ctx: &mut TxContext) {
        let (cap, metadata) = coin::create_currency(witness, 6, b"DRAGON", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(cap, tx_context::sender(ctx))
    }

    entry fun mint(cap: &mut TreasuryCap<DRAGON>, value: u64, recipient: address, ctx: &mut TxContext) {
        coin::mint_and_transfer(cap, value, recipient, ctx);
    }

    entry fun burn(cap: &mut TreasuryCap<DRAGON>, c: Coin<DRAGON>) {
        coin::burn(cap, c);
    }

    #[test_only]
    use sui::test_scenario as ts;
    #[test_only]
    use std::string;
    #[test_only]
    const DUMMY: address = @0xCAFE;

    #[test]
    fun test_init_and_mint() {
        let d = DRAGON{};
        let ctx = tx_context::dummy();
        let ts = ts::begin(tx_context::sender(&ctx));
        init(d, &mut ctx);
        ts::next_tx(&mut ts, tx_context::sender(&ctx));
        // test metadata
        {
            let metadata = ts::take_immutable<coin::CoinMetadata<DRAGON>>(&ts);
            let symbol = coin::get_symbol(&metadata);
            let s = string::from_ascii(symbol);
            assert!(*string::bytes(&s) == b"DRAGON", 1);
            ts::return_immutable(metadata);
        };
        // mint 1_000_000_000 DRAGON
        ts::next_tx(&mut ts, tx_context::sender(&ctx));
        {
            let cap = ts::take_from_sender<TreasuryCap<DRAGON>>(&ts);
            mint(&mut cap, 1_000_000_000, DUMMY, &mut ctx);
            ts::return_to_sender(&ts, cap);
        };
        // check DRAGON
        ts::next_tx(&mut ts, DUMMY);
        {
            let c = ts::take_from_sender<Coin<DRAGON>>(&ts);
            assert!(coin::value(&c) == 1_000_000_000, 0);
            ts::return_to_sender(&ts, c);
        };
        ts::end(ts);
    }
}