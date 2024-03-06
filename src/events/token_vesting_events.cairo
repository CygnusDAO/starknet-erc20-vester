pub mod Events {
    use starknet::{ContractAddress};
    use token_vesting::types::token_vesting_types::VestingSchedule;

    #[derive(Drop, starknet::Event)]
    pub struct Release {
        pub vesting_schedule_id: felt252,
        pub beneficiary: ContractAddress,
        pub caller: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewTokenVesting {
        pub vesting_schedule: VestingSchedule,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Revoke {
        pub vesting_schedule: VestingSchedule,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdraw {
        pub caller: ContractAddress,
        pub amount: u256
    }
}
