use core::traits::TryInto;

#[starknet::contract]
mod comde {
    use zeroable::Zeroable;
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use array::{Array, ArrayTrait};
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::deploy_syscall;
    use alexandria::storage::list::{List, ListTrait};

    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _class_hash_erc20: ClassHash,
        _sources: List<ContractAddress>,
        _source_components: LegacyMap<ContractAddress, List<felt252>>,
        _components: List<felt252>,
        _addresses: LegacyMap::<felt252, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Compose: Compose,
        Decompose: Decompose,
        Register: Register,
    }

    #[derive(Drop, starknet::Event)]
    struct Compose {
        time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Decompose {
        time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Register {
        time: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        class_hash: felt252,
    ) {
        self._class_hash_erc20.write(class_hash.try_into().unwrap());
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

    #[generate_trait]
    #[external(v0)]
    impl Comde of ComdeTrait {
        fn components(self: @ContractState) -> Array<felt252> {
            self._components.read().array()
        }
        fn register_component(ref self: ContractState, sk: felt252, name: felt252, symbol: felt252) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] Component not already registered
            let address = self._addresses.read(sk);
            assert(address.is_zero(), 'Component already registered');
            // [Effect] Deploy component as ERC20 contract
            let contract_address : felt252 = get_contract_address().into();
            let class_hash = self._class_hash_erc20.read();
            let mut calldata : Array<felt252> = ArrayTrait::new();
            calldata.append(name);
            calldata.append(symbol);
            calldata.append(contract_address); // owner
            let (address, _) = deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
            // [Effect] Register component
            let mut components = self._components.read();
            components.append(sk);
            self._addresses.write(sk, address);
        }
        fn delete_component(ref self: ContractState, sk: felt252) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] Component already registered
            let address = self._addresses.read(sk);
            assert(!address.is_zero(), 'Component not registered');
            // [Effect] Delete component
            self._addresses.write(sk, Zeroable::zero());
        }
        fn register_source(ref self: ContractState, address: ContractAddress, components: Array<felt252>) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Effect] Store components
            let mut stored_components = self._source_components.read(address);
            let mut index = stored_components.len();
            loop {
                if index == 0 {
                    break ();
                }
                stored_components.pop_front();
            };
            loop {
                if index == components.len() {
                    break ();
                }
                let component = *components[index];
                stored_components.append(component);
            };
            // [Effect] Store source
            let mut sources = self._sources.read();
            sources.append(address);
        }
        fn compose(self: @ContractState, address: ContractAddress) {}
        fn decompose(self: @ContractState, address: ContractAddress, token_id: u256) {}
    }

    #[generate_trait]
    impl Internal of InternalTrait {
    }
}
