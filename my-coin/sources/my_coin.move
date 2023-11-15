module example::mycoin {
  use std::option;
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};

  struct MYCOIN has drop {}

  fun init(witness: MYCOIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(witness, 6, b"MYCOIN", b"", b"", option::none(), ctx);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, tx_context::sender(ctx))
  }

  #[test_only]
  use sui::types;

  #[test]
  public fun test_one_time_witness() {
    let otw = MYCOIN{};
    assert!(types::is_one_time_witness(&otw), 0);
  }
}