//! # Ubuntu Secure Pallet
//!
//! Ubuntu Secure: Distributed Consensus Operating System
//!
//! This pallet transforms Ubuntu into a distributed blockchain where every system call
//! requires consensus from multiple nodes. It implements the core consensus mechanism
//! for validating system operations across 5 devices.
//!
//! ## Overview
//!
//! Phase 1 Implementation - Basic Consensus:
//! - System call transaction processing
//! - Multi-node voting mechanism
//! - Consensus validation (3/5 threshold)
//! - OS state management on-chain
//!
//! Every security-critical operation (file writes, process execution, permission changes)
//! becomes a blockchain transaction requiring distributed consensus before execution.

#![cfg_attr(not(feature = "std"), no_std)]

pub use pallet::*;

#[cfg(test)]
mod mock;

#[cfg(test)]
mod tests;

#[cfg(feature = "runtime-benchmarks")]
mod benchmarking;
pub mod weights;
pub use weights::*;

#[frame_support::pallet]
pub mod pallet {
	use super::*;
	use frame_support::pallet_prelude::*;
	use frame_system::pallet_prelude::*;
	use codec::{Decode, Encode};
	use scale_info::TypeInfo;

	#[pallet::pallet]
	pub struct Pallet<T>(_);

	/// Configuration trait for Ubuntu Secure pallet
	#[pallet::config]
	pub trait Config: frame_system::Config {
		type RuntimeEvent: From<Event<Self>> + IsType<<Self as frame_system::Config>::RuntimeEvent>;
		type WeightInfo: WeightInfo;
	}

	/// System call transaction types based on Ubuntu Secure classification
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub enum SyscallType {
		FileOpen,
		FileWrite,
		ProcessExec,
		PermissionChange,
		NetworkOperation,
	}

	/// Transaction classification for consensus requirements
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub enum TransactionClass {
		ClassA, // Security-critical: requires 3/5 consensus
		ClassB, // Performance-critical: cached consensus
		ClassC, // Non-critical: local only
	}

	/// Node types in the Ubuntu Secure network
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub enum NodeType {
		Laptop,    // Primary viewport (potentially compromised)
		Phone,     // ARM architecture
		Pi,        // RISC-V architecture
		Cloud,     // x86 cloud instance
		Friend,    // Social trust validation
	}

	/// Vote decision for consensus
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub enum Vote {
		Approve,
		Deny,
		Abstain,
	}

	/// System call transaction structure
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub struct SyscallTransaction<AccountId> {
		pub caller: AccountId,
		pub syscall_type: SyscallType,
		pub path: Vec<u8>, // File path or executable path
		pub flags: u32,    // Operation flags
		pub class: TransactionClass,
		pub timestamp: u64,
		pub signature: Vec<u8>, // Cryptographic signature
	}

	/// Node vote record
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub struct NodeVote<AccountId> {
		pub node_id: AccountId,
		pub node_type: NodeType,
		pub vote: Vote,
		pub reason: Vec<u8>,
		pub timestamp: u64,
	}

	/// Consensus result for a transaction
	#[derive(Encode, Decode, Clone, PartialEq, Eq, RuntimeDebug, TypeInfo)]
	pub struct ConsensusResult {
		pub approved: bool,
		pub votes_for: u32,
		pub votes_against: u32,
		pub total_votes: u32,
		pub threshold_met: bool,
	}

	/// Storage: Pending system call transactions awaiting consensus
	#[pallet::storage]
	pub type PendingTransactions<T: Config> = StorageMap<
		_,
		Blake2_128Concat,
		T::Hash, // Transaction hash
		SyscallTransaction<T::AccountId>,
		OptionQuery,
	>;

	/// Storage: Votes for each transaction
	#[pallet::storage]
	pub type TransactionVotes<T: Config> = StorageDoubleMap<
		_,
		Blake2_128Concat,
		T::Hash, // Transaction hash
		Blake2_128Concat,
		T::AccountId, // Voter node ID
		NodeVote<T::AccountId>,
		OptionQuery,
	>;

	/// Storage: Consensus results
	#[pallet::storage]
	pub type ConsensusResults<T: Config> = StorageMap<
		_,
		Blake2_128Concat,
		T::Hash, // Transaction hash
		ConsensusResult,
		OptionQuery,
	>;

	/// Storage: Registered nodes in the Ubuntu Secure network
	#[pallet::storage]
	pub type RegisteredNodes<T: Config> = StorageMap<
		_,
		Blake2_128Concat,
		T::AccountId,
		NodeType,
		OptionQuery,
	>;

	/// Storage: Node reputation scores (Byzantine fault tolerance)
	#[pallet::storage]
	pub type NodeReputation<T: Config> = StorageMap<
		_,
		Blake2_128Concat,
		T::AccountId,
		u32,
		ValueQuery,
	>;

	/// Storage: Current OS state hash (distributed state management)
	#[pallet::storage]
	pub type OSStateHash<T: Config> = StorageValue<_, T::Hash, OptionQuery>;

	/// Events emitted by Ubuntu Secure pallet
	#[pallet::event]
	#[pallet::generate_deposit(pub(super) fn deposit_event)]
	pub enum Event<T: Config> {
		/// System call transaction submitted for consensus
		SyscallSubmitted {
			transaction_hash: T::Hash,
			caller: T::AccountId,
			syscall_type: SyscallType,
			path: Vec<u8>,
		},

		/// Node voted on a transaction
		NodeVoted {
			transaction_hash: T::Hash,
			voter: T::AccountId,
			node_type: NodeType,
			vote: Vote,
		},

		/// Consensus reached for a transaction
		ConsensusReached {
			transaction_hash: T::Hash,
			approved: bool,
			votes_for: u32,
			votes_against: u32,
		},

		/// Node registered in Ubuntu Secure network
		NodeRegistered {
			node_id: T::AccountId,
			node_type: NodeType,
		},

		/// OS state updated
		OSStateUpdated {
			new_state_hash: T::Hash,
			updater: T::AccountId,
		},

		/// Malicious behavior detected
		MaliciousBehaviorDetected {
			node_id: T::AccountId,
			reputation: u32,
		},
	}

	/// Errors that can be returned by Ubuntu Secure pallet
	#[pallet::error]
	pub enum Error<T> {
		/// Transaction not found
		TransactionNotFound,
		/// Node not registered
		NodeNotRegistered,
		/// Already voted on this transaction
		AlreadyVoted,
		/// Consensus already reached
		ConsensusAlreadyReached,
		/// Insufficient nodes for consensus
		InsufficientNodes,
		/// Invalid signature
		InvalidSignature,
		/// Operation not permitted (consensus denied)
		OperationDenied,
		/// Node reputation too low
		LowReputation,
	}

	/// Ubuntu Secure dispatchable functions
	#[pallet::call]
	impl<T: Config> Pallet<T> {
		/// Register a node in the Ubuntu Secure network
		/// Each of the 5 devices must register with their node type
		#[pallet::call_index(0)]
		#[pallet::weight(T::WeightInfo::do_something())]
		pub fn register_node(
			origin: OriginFor<T>,
			node_type: NodeType,
		) -> DispatchResult {
			let who = ensure_signed(origin)?;

			// Register the node
			RegisteredNodes::<T>::insert(&who, &node_type);

			// Initialize reputation score
			NodeReputation::<T>::insert(&who, 100u32);

			// Emit event
			Self::deposit_event(Event::NodeRegistered {
				node_id: who,
				node_type,
			});

			Ok(())
		}

		/// Submit a system call transaction for consensus
		/// This is called when a security-critical operation needs validation
		#[pallet::call_index(1)]
		#[pallet::weight(T::WeightInfo::do_something())]
		pub fn submit_syscall(
			origin: OriginFor<T>,
			syscall_type: SyscallType,
			path: Vec<u8>,
			flags: u32,
			class: TransactionClass,
		) -> DispatchResult {
			let who = ensure_signed(origin)?;

			// Create transaction
			let transaction = SyscallTransaction {
				caller: who.clone(),
				syscall_type: syscall_type.clone(),
				path: path.clone(),
				flags,
				class,
				timestamp: <frame_system::Pallet<T>>::block_number().saturated_into::<u64>(),
				signature: vec![], // Simplified for Phase 1
			};

			// Generate transaction hash
			let transaction_hash = T::Hashing::hash_of(&transaction);

			// Store pending transaction
			PendingTransactions::<T>::insert(&transaction_hash, &transaction);

			// Emit event
			Self::deposit_event(Event::SyscallSubmitted {
				transaction_hash,
				caller: who,
				syscall_type,
				path,
			});

			Ok(())
		}

		/// Vote on a pending transaction
		/// Each of the 5 nodes votes APPROVE/DENY based on their validation
		#[pallet::call_index(2)]
		#[pallet::weight(T::WeightInfo::do_something())]
		pub fn vote_on_transaction(
			origin: OriginFor<T>,
			transaction_hash: T::Hash,
			vote: Vote,
			reason: Vec<u8>,
		) -> DispatchResult {
			let who = ensure_signed(origin)?;

			// Ensure node is registered
			let node_type = RegisteredNodes::<T>::get(&who)
				.ok_or(Error::<T>::NodeNotRegistered)?;

			// Ensure transaction exists
			ensure!(
				PendingTransactions::<T>::contains_key(&transaction_hash),
				Error::<T>::TransactionNotFound
			);

			// Ensure node hasn't already voted
			ensure!(
				!TransactionVotes::<T>::contains_key(&transaction_hash, &who),
				Error::<T>::AlreadyVoted
			);

			// Ensure consensus not already reached
			ensure!(
				!ConsensusResults::<T>::contains_key(&transaction_hash),
				Error::<T>::ConsensusAlreadyReached
			);

			// Create vote record
			let node_vote = NodeVote {
				node_id: who.clone(),
				node_type: node_type.clone(),
				vote: vote.clone(),
				reason,
				timestamp: <frame_system::Pallet<T>>::block_number().saturated_into::<u64>(),
			};

			// Store vote
			TransactionVotes::<T>::insert(&transaction_hash, &who, &node_vote);

			// Emit event
			Self::deposit_event(Event::NodeVoted {
				transaction_hash,
				voter: who,
				node_type,
				vote,
			});

			// Check if consensus is reached
			Self::check_consensus(&transaction_hash)?;

			Ok(())
		}

		/// Finalize consensus result and execute/deny operation
		/// Called after votes are collected to determine final outcome
		#[pallet::call_index(3)]
		#[pallet::weight(T::WeightInfo::do_something())]
		pub fn finalize_consensus(
			origin: OriginFor<T>,
			transaction_hash: T::Hash,
		) -> DispatchResult {
			let _who = ensure_signed(origin)?;

			// Ensure transaction exists
			ensure!(
				PendingTransactions::<T>::contains_key(&transaction_hash),
				Error::<T>::TransactionNotFound
			);

			// Check and finalize consensus
			Self::check_consensus(&transaction_hash)?;

			Ok(())
		}
	}

	/// Helper functions for Ubuntu Secure
	impl<T: Config> Pallet<T> {
		/// Check if consensus is reached for a transaction
		/// Ubuntu Secure requires 3/5 nodes to approve for consensus
		fn check_consensus(transaction_hash: &T::Hash) -> DispatchResult {
			let mut votes_for = 0u32;
			let mut votes_against = 0u32;
			let mut total_votes = 0u32;

			// Count all votes for this transaction
			for (_voter, vote_record) in TransactionVotes::<T>::iter_prefix(transaction_hash) {
				total_votes += 1;
				match vote_record.vote {
					Vote::Approve => votes_for += 1,
					Vote::Deny => votes_against += 1,
					Vote::Abstain => {}, // Abstain doesn't count toward consensus
				}
			}

			// Ubuntu Secure consensus rules:
			// - Need at least 3 votes for consensus
			// - Need 3/5 majority for approval (60%)
			let threshold_met = total_votes >= 3;
			let approved = threshold_met && votes_for >= 3;

			// If we have enough votes, finalize consensus
			if threshold_met || total_votes >= 5 {
				let consensus_result = ConsensusResult {
					approved,
					votes_for,
					votes_against,
					total_votes,
					threshold_met,
				};

				// Store consensus result
				ConsensusResults::<T>::insert(transaction_hash, &consensus_result);

				// Remove from pending
				PendingTransactions::<T>::remove(transaction_hash);

				// Emit consensus event
				Self::deposit_event(Event::ConsensusReached {
					transaction_hash: *transaction_hash,
					approved,
					votes_for,
					votes_against,
				});

				// Update node reputations based on voting behavior
				Self::update_node_reputations(transaction_hash, &consensus_result);
			}

			Ok(())
		}

		/// Update node reputation scores based on voting behavior
		/// Detect and penalize Byzantine behavior
		fn update_node_reputations(
			transaction_hash: &T::Hash,
			consensus_result: &ConsensusResult,
		) {
			// Simple reputation algorithm for Phase 1
			// In production, this would be more sophisticated
			for (_voter, vote_record) in TransactionVotes::<T>::iter_prefix(transaction_hash) {
				let current_reputation = NodeReputation::<T>::get(&vote_record.node_id);

				// Reward nodes that voted with consensus
				let new_reputation = if
					(consensus_result.approved && vote_record.vote == Vote::Approve) ||
					(!consensus_result.approved && vote_record.vote == Vote::Deny)
				{
					current_reputation.saturating_add(1) // Reward correct vote
				} else {
					current_reputation.saturating_sub(2) // Penalize incorrect vote
				};

				NodeReputation::<T>::insert(&vote_record.node_id, new_reputation);

				// Detect malicious behavior (reputation below threshold)
				if new_reputation < 50 {
					Self::deposit_event(Event::MaliciousBehaviorDetected {
						node_id: vote_record.node_id.clone(),
						reputation: new_reputation,
					});
				}
			}
		}
	}
}