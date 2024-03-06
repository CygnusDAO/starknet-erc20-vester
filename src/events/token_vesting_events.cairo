pub mod Events {
    use starknet::{ContractAddress};
    use token_vesting::types::token_vesting_types::VestingSchedule;

    /// Transfer
    #[derive(Drop, starknet::Event)]
    pub struct NewTokenVesting {
        pub token_vesting: VestingSchedule,
    }
}
