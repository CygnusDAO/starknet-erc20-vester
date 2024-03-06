#[starknet::contract]
pub mod SnakeTokenVesting {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use token_vesting::contracts::interface::ITokenVesting;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    /// # Imports
    use token_vesting::types::token_vesting_types::VestingSchedule;
    use core::{integer::BoundedInt, poseidon::poseidon_hash_span, num::traits::Zero};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    /// # Errors
    use token_vesting::errors::token_vesting_errors::Errors;

    /// # Events
    use token_vesting::events::token_vesting_events::Events::{Release, NewTokenVesting, Revoke, Withdraw};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Release: Release,
        NewTokenVesting: NewTokenVesting,
        Revoke: Revoke,
        Withdraw: Withdraw
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        owner: ContractAddress,
        token: IERC20Dispatcher,
        reentrant_guard: bool,
        /// Vesting schedule id's "array"
        vesting_schedule_ids: LegacyMap::<u32, felt252>,
        vesting_schedule_ids_length: u32,
        /// Mapping of ID => VestingSchedule struct
        vesting_schedules: LegacyMap::<felt252, VestingSchedule>,
        vesting_schedules_total_amount: u256,
        /// Count of user vesting schedules
        holders_vesting_count: LegacyMap::<ContractAddress, u32>
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, token: ContractAddress) {
        /// Store admin
        self.owner.write(owner);

        /// Store vested token
        self.token.write(IERC20Dispatcher { contract_address: token });
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl TokenVestingImpl of ITokenVesting<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ITokenVesting
        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_token(self: @ContractState) -> ContractAddress {
            self.token.read().contract_address
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_current_time(self: @ContractState) -> u256 {
            /// Convert to u256 to follow `TokenVesting.sol` but maybe better to keep u64?
            get_block_timestamp().into()
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedule(self: @ContractState, vesting_schedule_id: felt252) -> VestingSchedule {
            self.vesting_schedules.read(vesting_schedule_id)
        }
        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_id_at_index(self: @ContractState, index: u32) -> felt252 {
            /// # Error
            /// * `INDEX_OUT_OF_BOUNDS`
            assert(index < self.get_vesting_schedules_count(), Errors::INDEX_OUT_OF_BOUNDS);

            /// Get vesting schedule at `index`
            self.vesting_schedule_ids.read(index)
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_withdrawable_amount(self: @ContractState) -> u256 {
            /// Get the balance of token we own and the amount in vesting schedules
            let balance = self.token.read().balance_of(get_contract_address());
            let vesting_schedules_amount = self.vesting_schedules_total_amount.read();

            balance - vesting_schedules_amount
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedules_count(self: @ContractState) -> u32 {
            self.vesting_schedule_ids_length.read()
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedules_total_amount(self: @ContractState) -> u256 {
            self.vesting_schedules_total_amount.read()
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_vesting_schedules_count_by_beneficiary(self: @ContractState, beneficiary: ContractAddress) -> u32 {
            self.holders_vesting_count.read(beneficiary)
        }

        /// # Implementation
        /// * ITokenVesting
        fn get_last_vesting_schedule_for_holder(self: @ContractState, holder: ContractAddress) -> VestingSchedule {
            /// Get holder's total vesting counts - 1
            let index = self.holders_vesting_count.read(holder) - 1;

            /// Compute the vesting id for the holder at index 
            let vesting_schedule_id = self.compute_vesting_schedule_id_for_address_and_index(holder, index);

            /// Return the last vesting ID for holder
            self.vesting_schedules.read(vesting_schedule_id)
        }

        /// # Implementation
        /// * ITokenVesting
        fn compute_vesting_schedule_id_for_address_and_index(
            self: @ContractState, holder: ContractAddress, index: u32
        ) -> felt252 {
            /// We compute the Poseidon hash of the holder and index instead of the sn_keccak
            let arr: Array<felt252> = array![holder.into(), index.into()];

            poseidon_hash_span(arr.span())
        }


        /// # Implementation
        /// * ITokenVesting
        fn compute_next_vesting_schedule_id_for_holder(self: @ContractState, holder: ContractAddress) -> felt252 {
            /// Get holder's total vesting counts
            let index = self.holders_vesting_count.read(holder);

            /// Return the next vesting ID for holder
            self.compute_vesting_schedule_id_for_address_and_index(holder, index)
        }

        /// # Implementation
        /// * ITokenVesting
        fn compute_releasable_amount(self: @ContractState, vesting_schedule_id: felt252) -> u256 {
            /// Check that vesting schedule is not revoked
            self._only_if_vesting_schedule_not_revoked(vesting_schedule_id);

            /// Get vesting scehdule struct 
            let vesting_schedule: VestingSchedule = self.vesting_schedules.read(vesting_schedule_id);

            /// Compute token amount that can be relased
            self._compute_releasable_amounts(vesting_schedule)
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                      NON-CONSTANT FUNCTIONS
        /// ---------------------------------------------------------------------------------------------------

        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ITokenVesting
        fn create_vesting_schedule(
            ref self: ContractState,
            beneficiary: ContractAddress,
            start: u256,
            cliff: u256,
            duration: u256,
            slice_period_seconds: u256,
            revocable: bool,
            amount: u256
        ) {
            /// Check caller is owner of the vester
            self._only_owner();

            /// # Error
            /// * `INSUFFICIENT_FUNDS` - Avoid if amount is more than withdrawable
            assert(self.get_withdrawable_amount() >= amount, Errors::INSUFFICIENT_FUNDS);

            /// # Error
            /// * `DURATION_CANT_BE_ZERO`
            assert(duration > 0, Errors::DURATION_CANT_BE_ZERO);

            /// # Error
            /// * `CANT_VEST_ZERO` - Avoid vesting 0 tokens
            assert(amount > 0, Errors::CANT_VEST_ZERO_AMOUNT);

            /// # Error
            /// * `SLICE_PERIODS_ZERO` - Must be at least 1 second
            assert(slice_period_seconds > 0, Errors::SLICE_PERIODS_ZERO);

            /// # Error
            /// * `DURATION_BELOW_CLIFF` - Duration must be gte cliff
            assert(duration >= cliff, Errors::DURATION_BELOW_CLIFF);

            /// Get the next vesting schedule ID for holder
            let vesting_schedule_id = self.compute_next_vesting_schedule_id_for_holder(beneficiary);

            /// Add cliff to start timestamp
            let cliff = start + cliff;

            let vesting_schedule = VestingSchedule {
                beneficiary,
                cliff,
                start,
                duration,
                slice_period_seconds,
                revocable,
                amount,
                released: 0,
                revoked: false
            };

            /// Write to vesting schedules `array`
            self.vesting_schedules.write(vesting_schedule_id, vesting_schedule);

            /// Add total amount of vested tokens
            let vesting_schedules_amount = self.vesting_schedules_total_amount.read();
            self.vesting_schedules_total_amount.write(vesting_schedules_amount + amount);

            /// Add to vesting schedule IDs
            let ids_length = self.vesting_schedule_ids_length.read();
            self.vesting_schedule_ids.write(ids_length, vesting_schedule_id);
            self.vesting_schedule_ids_length.write(ids_length + 1);

            let current_vesting_count = self.holders_vesting_count.read(beneficiary);
            self.holders_vesting_count.write(beneficiary, current_vesting_count + 1);

            /// # Event
            /// * `NewTokenVesting`
            self.emit(NewTokenVesting { vesting_schedule })
        }

        /// # Security
        /// * Non-reentrant
        /// * If-not-revoked
        ///
        /// # Implementation
        /// * ITokenVesting
        fn release(ref self: ContractState, vesting_schedule_id: felt252, amount: u256) {
            /// Lock
            self._lock();

            /// Check schedule is not revoked
            self._only_if_vesting_schedule_not_revoked(vesting_schedule_id);

            /// Get vesting schedule, we overwrite if successful
            let mut vesting_schedule = self.vesting_schedules.read(vesting_schedule_id);

            /// Get beneficiary of the vesting schedule and caller
            let beneficiary = vesting_schedule.beneficiary;
            let caller = get_caller_address();

            /// # Error
            /// * `ONLY_BENEFICIARY_OR_OWNER` - Only beneficiary or owner can release vested tokens
            assert(caller == beneficiary || caller == self.owner.read(), Errors::ONLY_BENEFICIARY_OR_OWNER);

            /// # Error
            /// * `NOT_ENOUGH_VESTED_TOKENS` - Avoid if amount is higher than releasable
            assert(self._compute_releasable_amounts(vesting_schedule) >= amount, Errors::NOT_ENOUGH_VESTED_TOKENS);

            /// Update the vesting schedule for beneficiary with new released amounts
            vesting_schedule.released = vesting_schedule.released + amount;
            self.vesting_schedules.write(vesting_schedule_id, vesting_schedule);

            /// Update the total vested amounts
            let new_total_vesting_amounts = self.vesting_schedules_total_amount.read() + amount;
            self.vesting_schedules_total_amount.write(new_total_vesting_amounts);

            /// Transfer amount to beneficiary
            self.token.read().transfer(beneficiary, amount);

            /// Unlock
            self._unlock();

            /// # Event
            /// * `NewTokenVesting`
            self.emit(Release { vesting_schedule_id, beneficiary, caller, amount });
        }

        /// # Security
        /// * Non-reentrant
        /// * Only-owner
        ///
        /// # Implementation
        /// * ITokenVesting
        fn withdraw(ref self: ContractState, amount: u256) {
            /// Lock
            self._lock();

            /// Reverts if caller is not the owner
            self._only_owner();

            /// # Error
            /// * `INSUFFICIENT_FUNDS` - Avoid if amount is more than withdrawable amount
            assert(self.get_withdrawable_amount() >= amount, Errors::INSUFFICIENT_FUNDS);

            /// Transfer `amount` to owner
            let caller = get_caller_address();
            self.token.read().transfer(caller, amount);

            /// Unlock
            self._unlock();

            /// # Event
            /// * `Withdraw`
            self.emit(Withdraw { caller, amount });
        }

        /// # Security
        /// * Only-owner
        ///
        /// # Implementation
        /// * ITokenVesting
        fn revoke(ref self: ContractState, vesting_schedule_id: felt252) {
            /// Reverts if caller is not the owner
            self._only_owner();

            /// Check schedule is not revoked
            self._only_if_vesting_schedule_not_revoked(vesting_schedule_id);

            /// Get vesting schedule
            let vesting_schedule = self.vesting_schedules.read(vesting_schedule_id);

            /// # Error
            /// * `VESTING_SCHEDULE_NOT_REVOCABLE` - Avoid if not schedule not marked as revokable
            assert(vesting_schedule.revocable, Errors::VESTING_SCHEDULE_NOT_REVOCABLE);

            /// Get vested amount
            let vested_amount = self._compute_releasable_amounts(vesting_schedule);

            /// Release
            if vested_amount > 0 {
                self.release(vesting_schedule_id, vested_amount);
            }

            /// Release updates the vesting_schedule
            let mut vesting_schedule = self.vesting_schedules.read(vesting_schedule_id);

            /// Compute unreleased with updated vesting schedule
            let unreleased = vesting_schedule.amount - vesting_schedule.released;

            let vesting_schedules_amount = self.vesting_schedules_total_amount.read();
            self.vesting_schedules_total_amount.write(vesting_schedules_amount - unreleased);

            /// Update vesting schedule storage struct
            vesting_schedule.revoked = true;
            self.vesting_schedules.write(vesting_schedule_id, vesting_schedule);

            /// # Event
            /// * `Revoke`
            self.emit(Revoke { vesting_schedule });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Locks the contract preventing reentrancy
        fn _lock(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.reentrant_guard.read(), Errors::REENTRANT_CALL);

            /// Lock
            self.reentrant_guard.write(true);
        }

        /// Unlocks the reentrancy guard
        fn _unlock(ref self: ContractState) {
            self.reentrant_guard.write(false)
        }

        /// Internal function to compute the amount of that can be relased according to its vesting schedule
        fn _compute_releasable_amounts(self: @ContractState, vesting_schedule: VestingSchedule) -> u256 {
            /// Current timestmap in seconds
            let current_time = self.get_current_time();

            /// If the current time is before the cliff, no tokens are releasable.
            if current_time < vesting_schedule.cliff || vesting_schedule.revoked {
                return 0;
            }

            // If the current time is after the vesting period, all tokens are releasable,
            // minus the amount already released.
            if current_time >= vesting_schedule.start + vesting_schedule.duration {
                return vesting_schedule.amount - vesting_schedule.released;
            }

            // Otherwise, some tokens are releasable.
            let time_from_start = current_time - vesting_schedule.start;
            let seconds_per_slice = vesting_schedule.slice_period_seconds;
            let vested_slice_periods = time_from_start / seconds_per_slice;
            let vested_seconds = vested_slice_periods * seconds_per_slice;
            let vested_amount = (vesting_schedule.amount * vested_seconds) / vesting_schedule.duration;
            vested_amount - vesting_schedule.released
        }

        /// Modifier function called before revoke, release and compute
        ///
        /// # Arguments
        /// * `vesting_schedule_id` - The ID of the vesting schedule
        fn _only_if_vesting_schedule_not_revoked(self: @ContractState, vesting_schedule_id: felt252) {
            /// Get vesting schedule
            let vesting_schedule = self.vesting_schedules.read(vesting_schedule_id);

            /// # Error
            /// * `VESTING_SCHEDULE_IS_REVOKED` - Reverts if the vesting schedule is revoked by the user
            assert(!vesting_schedule.revoked, Errors::VESTING_SCHEDULE_IS_REVOKED);
        }

        /// Modifier function called for owner only functions
        fn _only_owner(self: @ContractState) {
            /// # Error
            /// * `CALLER_NOT_OWNER` - Reverts if the caller is not the vester owner
            assert(get_caller_address() == self.owner.read(), Errors::CALLER_NOT_OWNER);
        }
    }
}
