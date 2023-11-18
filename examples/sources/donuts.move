#[lint_allow(self_transfer)]
module examples::donuts {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    const ENotEnough: u64 = 0;

    // Capability that grants an owner the right to collect profits.
    struct ShopOwnerCap has key { id: UID }

    struct Donut has key { id: UID }

    struct DonutShop has key {
        id: UID,
        price: u64,
        balance: Balance<SUI>
    }

    public fun price(shop: &DonutShop): u64 {
        shop.price
    }

    public fun balance(shop: &DonutShop): &Balance<SUI> {
        &shop.balance
    }

    public fun id(cap: &ShopOwnerCap): &UID {
        &cap.id
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(ShopOwnerCap{
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(DonutShop {
            id: object::new(ctx),
            price: 1000,
            balance: balance::zero()
        })
    } 

    public entry fun buy_donut(
        shop: &mut DonutShop, payment: &mut Coin<SUI>, ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= shop.price, ENotEnough);

        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, shop.price);

        balance::join(&mut shop.balance, paid);

        transfer::transfer(Donut {
            id: object::new(ctx)
        }, tx_context::sender(ctx))
    }

    public entry fun eat_donut(d: Donut) {
        let Donut { id } = d;
        object::delete(id);
    }

    public entry fun collect_profits(
        _: &ShopOwnerCap, shop: &mut DonutShop, ctx: &mut TxContext
    ) {
        let amount = balance::value(&shop.balance);
        let profits = coin::take(&mut shop.balance, amount, ctx);

        transfer::public_transfer(profits, tx_context::sender(ctx));
    }

    #[test_only]
    use sui::test_scenario as ts;
    #[test_only]
    const BUYER: address = @0xCA;
    #[test_only]
    const SELLER: address = @0xCB;

    #[test]
    fun test_donuts_init() {
        let test_scenario_val = ts::begin(SELLER);
        let ts = &mut test_scenario_val;
        {
            ts::next_tx(ts, SELLER);
            init(ts::ctx(ts));
        };
        {
            ts::next_tx(ts, SELLER);
            let shop: DonutShop = ts::take_shared(ts);
            // debug::print(&shop);
            ts::return_shared(shop);
        };
        ts::end(test_scenario_val);
    }

    #[test]
    fun test_buy_and_eat() {
        // SELLER initilize
        let ts = ts::begin(SELLER);
        let ts_mut_val = &mut ts;
        {
            init(ts::ctx(ts_mut_val));
        };
        // BUYER gets coin
        ts::next_tx(ts_mut_val, BUYER);
        {
            let b = balance::create_for_testing<SUI>(1_000_000_000);
            let c = coin::zero<SUI>(ts::ctx(ts_mut_val));
            let zero_balance = coin::balance_mut(&mut c);
            balance::join(zero_balance, b);
            transfer::public_transfer(c, BUYER);
        };
        // BUYER buys donut
        ts::next_tx(ts_mut_val, BUYER);
        {
            let c = ts::take_from_sender(ts_mut_val);
            let shop = ts::take_shared<DonutShop>(ts_mut_val);
            // BUYER buys 4 donuts.
            buy_donut(&mut shop, &mut c, ts::ctx(ts_mut_val));
            buy_donut(&mut shop, &mut c, ts::ctx(ts_mut_val));
            buy_donut(&mut shop, &mut c, ts::ctx(ts_mut_val));
            buy_donut(&mut shop, &mut c, ts::ctx(ts_mut_val));
            ts::return_shared(shop);
            ts::return_to_sender(ts_mut_val, c);
        };
        // BUYER eats donut
        ts::next_tx(ts_mut_val, BUYER);
        {
            let d: Donut = ts::take_from_sender(ts_mut_val);
            eat_donut(d);
        };
        // SELLER collects profits
        ts::next_tx(ts_mut_val, SELLER);
        {
            let cap = ts::take_from_sender<ShopOwnerCap>(ts_mut_val);
            let shop = ts::take_shared<DonutShop>(ts_mut_val);
            collect_profits(&cap, &mut shop, ts::ctx(ts_mut_val));
            ts::return_to_sender(ts_mut_val, cap);
            ts::return_shared(shop);
        };
        // SELLER checks balance
        ts::next_tx(ts_mut_val, SELLER);
        {
            let c = ts::take_from_sender<Coin<SUI>>(ts_mut_val);
            let b = coin::balance(&c);
            assert!(balance::value(b) == 4000, 0);
            ts::return_to_sender(ts_mut_val, c);
        };
        ts::end(ts);
    }
}