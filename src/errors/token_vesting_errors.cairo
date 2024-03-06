/// Errors for `token_vesting.cairo`
pub mod Errors {
    pub const VESTING_SCHEDULE_IS_REVOKED: felt252 = 'vesting_schedule_revoked';
    pub const VESTING_TOKEN_CANT_BE_ZERO: felt252 = 'vesting_token_cant_be_zero';
    pub const CALLER_NOT_OWNER: felt252 = 'only_owner';
    pub const INDEX_OUT_OF_BOUNDS: felt252 = 'index_out_of_bounds';
    pub const REENTRANT_CALL: felt252 = 'reentrant_call';
    pub const INSUFFICIENT_FUNDS: felt252 = 'insufficient_funds';
    pub const CANT_VEST_ZERO_AMOUNT: felt252 = 'cant_vest_zero_amount';
    pub const SLICE_PERIODS_ZERO: felt252 = 'slice_periods_is_zero';
    pub const DURATION_BELOW_CLIFF: felt252 = 'duration_below_cliff';
    pub const ONLY_BENEFICIARY_OR_OWNER: felt252 = 'only_beneficiary_or_owner';
    pub const NOT_ENOUGH_VESTED_TOKENS: felt252 = 'not_enough_vested_tokens';
    pub const VESTING_SCHEDULE_NOT_REVOCABLE: felt252 = 'schedule_not_revocable';
    pub const DURATION_CANT_BE_ZERO: felt252 = 'duration_cant_be_zero';
}
