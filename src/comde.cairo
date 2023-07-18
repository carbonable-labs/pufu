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
    use super::super::interfaces::comde::IComde;

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
        owner: ContractAddress,
    ) {
        self._class_hash_erc20.write(class_hash.try_into().unwrap());
        self._owner.write(owner);
    }

    #[generate_trait]
    #[external(v0)]
    impl Ownable of IOwnable {
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

    #[external(v0)]
    impl Comde of IComde<ContractState> {
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
            let mut components = self._components.read();
            let mut index = 0;
            loop {
                if index == components.len() {
                    assert(false, 'Component not found');
                    break ();
                }
                let component = components.get(index).unwrap();
                if component == sk {
                    if index != components.len() - 1 {
                        let last_component = components.get(components.len() - 1).unwrap();
                        components.set(index, last_component);
                    }
                    components.pop_front();
                    break ();
                }
                index += 1;
            };
            self._addresses.write(sk, Zeroable::zero());
        }
        fn sources(self: @ContractState) -> Array<ContractAddress> {
            self._sources.read().array()
        }
        fn source_components(self: @ContractState, address: ContractAddress) -> Array<felt252> {
            self._source_components.read(address).array()
        }
        fn register_source(ref self: ContractState, address: ContractAddress, components: Array<felt252>) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] Source not already registered
            let mut source_components = self._source_components.read(address);
            assert(source_components.len() == 0, 'Source already registered');
            // [Effect] Store components
            let mut index = 0;
            loop {
                if index == components.len() {
                    break ();
                }
                let component = *components[index];
                source_components.append(component);
                index += 1;
            };
            // [Effect] Store source
            let mut sources = self._sources.read();
            sources.append(address);
        }
        fn delete_source(ref self: ContractState, address: ContractAddress) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] Source already registered
            let mut source_components = self._source_components.read(address);
            assert(source_components.len() != 0, 'Source not registered');
            // [Effect] Delete source
            let mut sources = self._sources.read();
            let mut index = 0;
            loop {
                if index == sources.len() {
                    assert(false, 'Source not found');
                    break ();
                }
                let source = sources.get(index).unwrap();
                if source == address {
                    if index != sources.len() - 1 {
                        let last_source = sources.get(sources.len() - 1).unwrap();
                        sources.set(index, last_source);
                    }
                    sources.pop_front();
                    break ();
                }
                index += 1;
            };
            // [Effect] Delete components
            let mut index = source_components.len() - 1;
            loop {
                if index == 0 {
                    break ();
                }
                source_components.pop_front();
            };
        }
        fn compose(self: @ContractState, address: ContractAddress) {}
        fn decompose(self: @ContractState, address: ContractAddress, token_id: u256) {}
    }

    #[generate_trait]
    impl Internal of IInternal {
    }
}

#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use core::result::ResultTrait;
    use core::traits::Into;
    use option::OptionTrait;
    use starknet::syscalls::deploy_syscall;
    use starknet::get_contract_address;
    use traits::TryInto;

    use test::test_utils::assert_eq;

    use super::comde;
    use super::super::interfaces::comde::{ IComdeDispatcher, IComdeDispatcherTrait };

    fn deploy_comde() -> IComdeDispatcher {
        let mut calldata = Default::default();
        // TODO: ERC20 class hash
        calldata.append(comde::TEST_CLASS_HASH);
        calldata.append(get_contract_address().into());
        let (address, _) = deploy_syscall(
            comde::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        ).unwrap();
        IComdeDispatcher { contract_address: address }
    }

    fn setup() -> (IComdeDispatcher,) {
        (deploy_comde(), )
    }

    #[test]
    #[available_gas(30000000)]
    fn test_initialization() {
        let (contract,) = setup();
        assert(contract.components().len() == 0, 'Initialization failed');
    }

    #[test]
    #[available_gas(30000000)]
    fn test_register_component() {
        let (contract,) = setup();
        // contract.register_component(sk: 'SK', name: 'NAME', symbol: 'SYMBOL');
        // assert(contract.components().len() == 1, 'Initialization failed');
    }

    #[test]
    #[available_gas(30000000)]
    fn test_delete_component() {
        let (contract,) = setup();
        // contract.register_component(sk: 'SK', name: 'NAME', symbol: 'SYMBOL');
        // contract.delete_component(sk: 'SK');
        // assert(contract.components().len() == 1, 'Initialization failed');
    }

    #[test]
    #[available_gas(30000000)]
    fn test_register_source() {
        let (contract,) = setup();
        // contract.register_component(sk: 'SK', name: 'NAME', symbol: 'SYMBOL');
        // assert(contract.components().len() == 1, 'Initialization failed');
    }

    #[test]
    #[available_gas(30000000)]
    fn test_decompose() {
        let (contract,) = setup();
        // contract.register_component(sk: 'SK', name: 'NAME', symbol: 'SYMBOL');
        // assert(contract.components().len() == 1, 'Initialization failed');
    }

    #[test]
    #[available_gas(30000000)]
    fn test_compose() {
        let (contract,) = setup();
        // contract.register_component(sk: 'SK', name: 'NAME', symbol: 'SYMBOL');
        // assert(contract.components().len() == 1, 'Initialization failed');
    }
}
