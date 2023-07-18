#[starknet::interface]
trait IERC20<TContractState> {
    fn mint(self: @TContractState, account: starknet::ContractAddress, amount: u256);

    fn burn(ref self: TContractState, amount: u256);

    fn balance_of(self: @TContractState, account: starknet::ContractAddress) -> u256;

    fn transfer_from(
        ref self: TContractState,
        sender: starknet::ContractAddress,
        recipient: starknet::ContractAddress,
        amount: u256
    ) -> bool;
}

#[starknet::contract]
mod erc20 {
    use super::IERC20;
    use zeroable::Zeroable;

    //
    // Storage
    //

    #[storage]
    struct Storage {
        _balances: LegacyMap<starknet::ContractAddress, u256>, 
    }

    //
    // Constructor
    //

    #[constructor]
    fn constructor(
        ref self: ContractState, initial_supply: u256, recipient: starknet::ContractAddress
    ) {}

    //
    // Interface impl
    //

    #[external(v0)]
    impl IERC20Impl of IERC20<ContractState> {
        fn balance_of(self: @ContractState, account: starknet::ContractAddress) -> u256 {
            self._balances.read(account)
        }

        fn transfer_from(
            ref self: ContractState,
            sender: starknet::ContractAddress,
            recipient: starknet::ContractAddress,
            amount: u256
        ) -> bool {
            self._transfer(sender, recipient, amount);
            true
        }

        fn mint(ref self: ContractState, amount: u256) {
            self._mint(recipient, initial_supply);
        }

        fn burn(ref self: ContractState, amount: u256) { //TODO implement burn
        }
    }

    //
    // Helpers
    //

    #[generate_trait]
    impl HelperImpl of HelperTrait {
        fn _mint(ref self: ContractState, recipient: starknet::ContractAddress, amount: u256) {
            let caller = get_caller_address();
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] recipient != 0
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            //[Effect] mint
            self._balances.write(recipient, self._balances.read(recipient) + amount);
        }
    }

    #[generate_trait]
    #[external(v0)]
    impl Ownable of OwnableTrait {
        fn owner(self: @ContractState) -> ContractAddress {
            self._owner.read()
        }
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            // [Check] Caller is owner
            let caller = get_caller_address();
            let owner = self._owner.read();
            assert(caller == owner, 'Caller is not owner');

            // [Check] New owner is not 0
            assert(!new_owner.is_zero(), 'New owner cannot be 0');

            // [Effect] Transfer ownership
            self._owner.write(new_owner);
        }
        fn renounce_ownership(ref self: ContractState) {
            // [Check] Caller is owner
            let caller = get_caller_address();
            let owner = self._owner.read();
            assert(caller == owner, 'Caller is not owner');

            // [Effect] Renounce ownership
            self._owner.write(Zeroable::zero());
        }
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self._owner.read();
            assert(caller == owner, 'Caller is not owner');
        }
    }
}
