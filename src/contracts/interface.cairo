/// This is a Cairo implementation of https://github.com/AbdelStark/token-vesting-contracts/blob/main/src/TokenVesting.sol
/// Which is released as under the Apache-2.0 license.
use starknet::ContractAddress;
use token_vesting::types::token_vesting_types::VestingSchedule;

#[starknet::interface]
pub trait ITokenVesting<T> {
    /// ---------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    /// ---------------------------------------------------------------------------------------------------

    /// # Returns
    /// * The address of the vested token
    fn get_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the vester owner
    fn owner(self: @T) -> ContractAddress;

    /// # Returns
    /// * The current timestamp in seconds
    fn get_current_time(self: @T) -> u256;

    /// # Returns
    /// * The vesting schedule information for a given identifier.
    fn get_vesting_schedule(self: @T, vesting_schedule_id: felt252) -> VestingSchedule;

    /// # Returns
    /// * The amount of tokens that can be withdrawn by the owner.
    fn get_withdrawable_amount(self: @T) -> u256;

    /// # Returns
    /// * The vesting schedule id at the given index.
    fn get_vesting_id_at_index(self: @T, index: u32) -> felt252;

    /// # Returns
    /// * The amount of vesting tokens that can be released
    fn compute_releasable_amount(self: @T, vesting_schedule_id: felt252) -> u256;

    /// # Returns 
    /// * The number of vesting schedules managed by this contract.
    fn get_vesting_schedules_count(self: @T) -> u32;

    /// # Returns 
    /// * The total amount of vested tokens
    fn get_vesting_schedules_total_amount(self: @T) -> u256;

    /// # Returns
    /// * The last vesting schedule for a given holder address.
    fn get_last_vesting_schedule_for_holder(self: @T, holder: ContractAddress) -> VestingSchedule;

    /// # Returns 
    /// * The number of vesting schedules associated to a beneficiary.
    fn get_vesting_schedules_count_by_beneficiary(self: @T, beneficiary: ContractAddress) -> u32;

    /// # Returns
    /// * The next vesting schedule for a given holder address.
    fn compute_next_vesting_schedule_id_for_holder(self: @T, holder: ContractAddress) -> felt252;

    /// # Returns
    /// * The vesting schedule identifier for an address and an index.
    fn compute_vesting_schedule_id_for_address_and_index(self: @T, holder: ContractAddress, index: u32) -> felt252;

    /// ---------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// ---------------------------------------------------------------------------------------------------

    /// Creates a vesting schedule
    /// 
    /// # Security
    /// * Only-owner
    fn create_vesting_schedule(
        ref self: T,
        beneficiary: ContractAddress,
        start: u256,
        cliff: u256,
        duration: u256,
        slice_period_seconds: u256,
        revocable: bool,
        amount: u256
    );

    /// # Security
    /// * Non-reentrant
    /// * Only-owner
    fn withdraw(ref self: T, amount: u256);

    /// # Security
    /// * Non-reentrant
    /// * If-not-revoked
    fn release(ref self: T, vesting_schedule_id: felt252, amount: u256);

    /// # Security
    /// * Non-reentrant
    /// * If-not-revoked
    fn revoke(ref self: T, vesting_schedule_id: felt252);
}

