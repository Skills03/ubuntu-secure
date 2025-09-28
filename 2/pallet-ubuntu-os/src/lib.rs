//! # Ubuntu OS Pallet
//!
//! A FRAME pallet for managing Ubuntu operating system operations on blockchain.
//! This pallet handles syscall consensus, device voting, and operation logging.
//!
//! ## Phase 2 Implementation
//! - Proper FRAME structure for OS operations
//! - Validator voting mechanism
//! - Operation categorization and permissions
//! - Event logging for audit trails

#![cfg_attr(not(feature = "std"), no_std)]

use frame_support::{
    decl_module, decl_storage, decl_event, decl_error,
    traits::{Get, Randomness},
    weights::{Weight, DispatchClass},
    dispatch::{DispatchResult, DispatchError},
    codec::{Encode, Decode},
};
use sp_std::{vec::Vec, collections::btree_map::BTreeMap};
use frame_system::ensure_signed;
use sp_runtime::traits::{Zero, Saturating};

/// OS operation types that require consensus
#[derive(Encode, Decode, Clone, PartialEq, Eq, Debug)]
pub enum OperationType {
    /// Sudo operations (elevated privileges)
    Sudo,
    /// File system writes to critical paths
    FileWrite,
    /// Network operations
    Network,
    /// Device access (camera, microphone, etc.)
    Device,
    /// Process execution
    Process,
    /// Memory operations
    Memory,
}

/// Voting decision from a validator
#[derive(Encode, Decode, Clone, PartialEq, Eq, Debug)]
pub enum Vote {
    Approve,
    Deny,
    Abstain,
}

/// OS operation request
#[derive(Encode, Decode, Clone, PartialEq, Eq, Debug)]
pub struct OSOperation<AccountId> {
    /// Who is requesting the operation
    pub requester: AccountId,
    /// Type of operation
    pub operation_type: OperationType,
    /// Operation details (command, file path, etc.)
    pub details: Vec<u8>,
    /// Hostname/device that originated the request
    pub origin_device: Vec<u8>,
    /// Block number when requested
    pub requested_at: u32,
}

/// Consensus result for an operation
#[derive(Encode, Decode, Clone, PartialEq, Eq, Debug)]
pub struct ConsensusResult {
    /// Total votes received
    pub total_votes: u32,
    /// Number of approve votes
    pub approve_votes: u32,
    /// Number of deny votes
    pub deny_votes: u32,
    /// Whether consensus was reached
    pub approved: bool,
}

/// Configure the pallet by specifying the parameters and types on which it depends.
pub trait Trait: frame_system::Trait {
    /// Because this pallet emits events, it depends on the runtime's definition of an event.
    type Event: From<Event<Self>> + Into<<Self as frame_system::Trait>::Event>;

    /// The origin which may vote on OS operations (typically validators)
    type VotingOrigin: frame_support::traits::EnsureOrigin<Self::Origin>;

    /// Minimum number of votes required for consensus
    type MinimumVotes: Get<u32>;

    /// Percentage of approve votes needed (out of 100)
    type ApprovalThreshold: Get<u32>;
}

// Storage items for the pallet
decl_storage! {
    trait Store for Module<T: Trait> as UbuntuOS {
        /// Pending OS operations awaiting consensus
        PendingOperations get(fn pending_operations):
            map hasher(blake2_128_concat) u32 => Option<OSOperation<T::AccountId>>;

        /// Votes for each operation
        OperationVotes get(fn operation_votes):
            double_map hasher(blake2_128_concat) u32, hasher(blake2_128_concat) T::AccountId
            => Option<Vote>;

        /// Next operation ID
        NextOperationId get(fn next_operation_id): u32 = 1;

        /// Approved validators who can vote on operations
        ApprovedValidators get(fn approved_validators):
            map hasher(blake2_128_concat) T::AccountId => bool;

        /// Device trust levels (0-100)
        DeviceTrust get(fn device_trust):
            map hasher(blake2_128_concat) Vec<u8> => u32;

        /// Operation history for audit trails
        OperationHistory get(fn operation_history):
            map hasher(blake2_128_concat) u32 => Option<(OSOperation<T::AccountId>, ConsensusResult)>;
    }
}

// Events emitted by the pallet
decl_event!(
    pub enum Event<T> where AccountId = <T as frame_system::Trait>::AccountId {
        /// An OS operation was submitted for consensus [operation_id, requester]
        OperationSubmitted(u32, AccountId),

        /// A validator voted on an operation [operation_id, voter, vote]
        VoteCast(u32, AccountId, Vote),

        /// Consensus was reached for an operation [operation_id, approved]
        ConsensusReached(u32, bool),

        /// An operation was executed [operation_id]
        OperationExecuted(u32),

        /// A validator was added [validator]
        ValidatorAdded(AccountId),

        /// Device trust level was updated [device, trust_level]
        DeviceTrustUpdated(Vec<u8>, u32),
    }
);

// Errors that can be returned by the pallet
decl_error! {
    pub enum Error for Module<T: Trait> {
        /// Operation not found
        OperationNotFound,
        /// Already voted on this operation
        AlreadyVoted,
        /// Not an approved validator
        NotValidator,
        /// Consensus already reached
        ConsensusAlreadyReached,
        /// Invalid operation details
        InvalidOperation,
        /// Insufficient permissions
        InsufficientPermissions,
    }
}

// Dispatchable functions for the pallet
decl_module! {
    pub struct Module<T: Trait> for enum Call where origin: T::Origin {
        // Error boilerplate
        type Error = Error<T>;

        // Events
        fn deposit_event() = default;

        // Constants
        const MinimumVotes: u32 = T::MinimumVotes::get();
        const ApprovalThreshold: u32 = T::ApprovalThreshold::get();

        /// Submit an OS operation for consensus
        #[weight = 10_000]
        pub fn submit_operation(
            origin,
            operation_type: OperationType,
            details: Vec<u8>,
            origin_device: Vec<u8>,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            let operation_id = Self::next_operation_id();

            let operation = OSOperation {
                requester: who.clone(),
                operation_type,
                details,
                origin_device,
                requested_at: frame_system::Module::<T>::block_number().saturated_into::<u32>(),
            };

            PendingOperations::<T>::insert(&operation_id, &operation);
            NextOperationId::mutate(|id| *id = id.saturating_add(1));

            Self::deposit_event(RawEvent::OperationSubmitted(operation_id, who));

            Ok(())
        }

        /// Vote on a pending operation (validators only)
        #[weight = 10_000]
        pub fn vote_on_operation(
            origin,
            operation_id: u32,
            vote: Vote,
        ) -> DispatchResult {
            let who = ensure_signed(origin)?;

            // Check if caller is an approved validator
            if !Self::approved_validators(&who) {
                return Err(Error::<T>::NotValidator.into());
            }

            // Check if operation exists
            let operation = Self::pending_operations(operation_id)
                .ok_or(Error::<T>::OperationNotFound)?;

            // Check if already voted
            if Self::operation_votes(operation_id, &who).is_some() {
                return Err(Error::<T>::AlreadyVoted.into());
            }

            // Record vote
            OperationVotes::<T>::insert(&operation_id, &who, &vote);

            Self::deposit_event(RawEvent::VoteCast(operation_id, who, vote));

            // Check if consensus is reached
            Self::check_consensus(operation_id)?;

            Ok(())
        }

        /// Add a validator (governance only)
        #[weight = 10_000]
        pub fn add_validator(
            origin,
            validator: T::AccountId,
        ) -> DispatchResult {
            // In production, this would require governance/sudo
            ensure_signed(origin)?;

            ApprovedValidators::<T>::insert(&validator, true);

            Self::deposit_event(RawEvent::ValidatorAdded(validator));

            Ok(())
        }

        /// Update device trust level
        #[weight = 10_000]
        pub fn update_device_trust(
            origin,
            device: Vec<u8>,
            trust_level: u32,
        ) -> DispatchResult {
            ensure_signed(origin)?;

            // Trust level should be 0-100
            let trust = if trust_level > 100 { 100 } else { trust_level };

            DeviceTrust::insert(&device, trust);

            Self::deposit_event(RawEvent::DeviceTrustUpdated(device, trust));

            Ok(())
        }
    }
}

impl<T: Trait> Module<T> {
    /// Check if consensus is reached for an operation
    fn check_consensus(operation_id: u32) -> DispatchResult {
        let operation = Self::pending_operations(operation_id)
            .ok_or(Error::<T>::OperationNotFound)?;

        // Count votes
        let mut total_votes = 0u32;
        let mut approve_votes = 0u32;
        let mut deny_votes = 0u32;

        // Iterate through all validators and their votes
        for (validator, _) in ApprovedValidators::<T>::iter() {
            if let Some(vote) = Self::operation_votes(operation_id, &validator) {
                total_votes = total_votes.saturating_add(1);
                match vote {
                    Vote::Approve => approve_votes = approve_votes.saturating_add(1),
                    Vote::Deny => deny_votes = deny_votes.saturating_add(1),
                    Vote::Abstain => {}, // Don't count abstentions
                }
            }
        }

        // Check if minimum votes reached
        if total_votes < T::MinimumVotes::get() {
            return Ok(()); // Not enough votes yet
        }

        // Calculate approval percentage
        let voting_total = approve_votes.saturating_add(deny_votes);
        let approval_percentage = if voting_total > 0 {
            (approve_votes * 100) / voting_total
        } else {
            0
        };

        let approved = approval_percentage >= T::ApprovalThreshold::get();

        let consensus_result = ConsensusResult {
            total_votes,
            approve_votes,
            deny_votes,
            approved,
        };

        // Store in history
        OperationHistory::<T>::insert(&operation_id, (&operation, &consensus_result));

        // Remove from pending
        PendingOperations::<T>::remove(&operation_id);

        // Clear votes (no longer needed)
        OperationVotes::<T>::remove_prefix(&operation_id);

        Self::deposit_event(RawEvent::ConsensusReached(operation_id, approved));

        if approved {
            Self::deposit_event(RawEvent::OperationExecuted(operation_id));
        }

        Ok(())
    }

    /// Get consensus result for an operation
    pub fn get_consensus_result(operation_id: u32) -> Option<bool> {
        Self::operation_history(operation_id).map(|(_, result)| result.approved)
    }

    /// Check if operation requires high consensus based on type
    pub fn requires_high_consensus(op_type: &OperationType) -> bool {
        match op_type {
            OperationType::Sudo => true,
            OperationType::FileWrite => true,
            OperationType::Device => true,
            _ => false,
        }
    }
}

// Integration tests
#[cfg(test)]
mod tests {
    use super::*;
    use frame_support::{
        assert_ok, assert_noop, impl_outer_origin, parameter_types, weights::Weight,
        traits::{OnInitialize, OnFinalize}
    };
    use sp_core::H256;
    use sp_runtime::{
        traits::{BlakeTwo256, IdentityLookup}, testing::Header, Perbill,
    };
    use frame_system as system;

    // Test that operations can be submitted and voted on
    #[test]
    fn submit_and_vote_works() {
        // Implementation of basic test
        // This would test the full flow of operation submission and voting
    }
}