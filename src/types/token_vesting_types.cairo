use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct VestingSchedule {
    pub beneficiary: ContractAddress,
    pub cliff: u256,
    pub start: u256,
    pub duration: u256,
    pub slice_period_seconds: u256,
    pub revocable: bool,
    pub amount: u256,
    pub released: u256,
    pub revoked: bool
}
