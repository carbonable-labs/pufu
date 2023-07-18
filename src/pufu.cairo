#[starknet::contract]
mod pufu {
    use zeroable::Zeroable;
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use array::{Array, ArrayTrait};
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::get_caller_address;
    use starknet::deploy_syscall;
    use alexandria::storage::list::{List, ListTrait};
    use super::super::interfaces::comde::IComde;
    use starknet::get_contract_address;
    use super::super::interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use super::super::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use alexandria::math::math;

    const TOKEN_QTY: u128 = 1;

    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _class_hash_erc20: ClassHash,
        _sources: List<ContractAddress>,
        _source_components: LegacyMap<ContractAddress, List<felt252>>,
        _components: List<felt252>,
        _component_addresses: LegacyMap::<felt252, ContractAddress>,
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
    fn constructor(ref self: ContractState, class_hash: felt252, owner: ContractAddress, ) {
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
        fn component_address(self: @ContractState, sk: felt252) -> ContractAddress {
            self._component_addresses.read(sk)
        }
        fn components(self: @ContractState) -> Array<felt252> {
            self._components.read().array()
        }
        fn register_component(
            ref self: ContractState, sk: felt252, name: felt252, symbol: felt252
        ) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] Component not already registered
            let address = self._component_addresses.read(sk);
            assert(address.is_zero(), 'Component already registered');
            // [Effect] Deploy component as ERC20 contract
            let contract_address: felt252 = get_contract_address().into();
            let class_hash = self._class_hash_erc20.read();
            let mut calldata: Array<felt252> = ArrayTrait::new();
            calldata.append(name);
            calldata.append(symbol);
            calldata.append(contract_address); // owner
            let (address, _) = deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
            // [Effect] Register component
            let mut components = self._components.read();
            components.append(sk);
            self._component_addresses.write(sk, address);
        }
        fn delete_component(ref self: ContractState, sk: felt252) {
            // [Check] Caller is owner
            self.assert_only_owner();
            // [Check] Component already registered
            let address = self._component_addresses.read(sk);
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
            self._component_addresses.write(sk, Zeroable::zero());
        }
        fn sources(self: @ContractState) -> Array<ContractAddress> {
            self._sources.read().array()
        }
        fn source_components(self: @ContractState, address: ContractAddress) -> Array<felt252> {
            self._source_components.read(address).array()
        }
        fn register_source(
            ref self: ContractState, address: ContractAddress, components: Array<felt252>
        ) {
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
                // [Check] Component is registered
                let component_address = self._component_addresses.read(component);
                assert(!component_address.is_zero(), 'Component not registered');
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
        fn decompose(self: @ContractState, address: ContractAddress, token_id: u256) {
            //[Check] caller is the ERC721 owner
            let caller = get_caller_address();
            let erc721_contract = IERC721Dispatcher { contract_address: address };
            let owner = erc721_contract.owner_of(token_id);
            assert(caller == owner, 'Only owner can decompose');

            let mut source_components = self._source_components.read(address);
            assert(source_components.len() != 0, 'No component registered');
            let mut index = 0;
            //[Effect] start decompose
            loop {
                if index == source_components.len() {
                    break ();
                }
                //get Component
                let component = source_components[index];
                //get erc20 component addresse
                let erc20_address = self._component_addresses.read(component);
                //load contract from dispatcher
                let erc_20_contract = IERC20Dispatcher { contract_address: erc20_address };
                //mint
                let qty = math::pow(TOKEN_QTY, erc_20_contract.decimals().into());
                erc_20_contract.mint(caller, qty.into());
                index += 1;
            }
        }
    }

    #[generate_trait]
    impl Internal of IInternal {}
}

#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use core::result::ResultTrait;
    use core::traits::Into;
    use option::OptionTrait;
    use starknet::syscalls::deploy_syscall;
    use starknet::get_contract_address;
    use starknet::contract_address_try_from_felt252;
    use traits::TryInto;

    use super::pufu;
    use super::super::interfaces::comde::{IComdeDispatcher, IComdeDispatcherTrait};
    use super::super::erc20::erc20;

    fn deploy_pufu() -> IComdeDispatcher {
        let mut calldata = Default::default();
        calldata.append(erc20::TEST_CLASS_HASH);
        calldata.append(get_contract_address().into());
        let (address, _) = deploy_syscall(
            pufu::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        IComdeDispatcher { contract_address: address }
    }

    fn setup() -> IComdeDispatcher {
        deploy_pufu()
    }

    #[test]
    #[available_gas(10000000)]
    fn test_initialization() {
        let contract = setup();
        assert(contract.components().len() == 0, 'Initialization failed');
        let address = contract.component_address(sk: 'SK');
        assert(address == Zeroable::zero(), 'Wrong address');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_register_component() {
        let contract = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        assert(contract.components().len() == 1, 'Registration failed');
        assert(*contract.components()[0] == sk, 'Wrong key');
        let address = contract.component_address(sk: sk);
        assert(address != Zeroable::zero(), 'Wrong address');
    }

    #[test]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_register_component_revert_already_registered() {
        let contract = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_delete_component() {
        let contract = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        contract.delete_component(sk: sk);
        assert(contract.components().len() == 0, 'Deletion failed');
        let address = contract.component_address(sk: 'SK');
        assert(address == Zeroable::zero(), 'Wrong address');
    }

    #[test]
    // Doesn't work since the assert failed in the impl and not in the test
    // #[should_panic(expected: ('Component not registered',))]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_delete_component_revert_not_registered() {
        let contract = setup();
        let sk = 'SK';
        contract.delete_component(sk: sk);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_register_source() {
        let contract = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        let address = contract_address_try_from_felt252(1).unwrap();
        contract.register_source(address: address, components: components);
        assert(contract.sources().len() == 1, 'Registration failed');
    }

    #[test]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_register_source_revert_already_registered() {
        let contract = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        let address = contract_address_try_from_felt252(1).unwrap();
        contract.register_source(address: address, components: components);
        let components = contract.components();
        let address = contract_address_try_from_felt252(1).unwrap();
        contract.register_source(address: address, components: components);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_delete_source() {
        let contract = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        let address = contract_address_try_from_felt252(1).unwrap();
        contract.register_source(address: address, components: components);
        let address = contract_address_try_from_felt252(1).unwrap();
        contract.delete_source(address: address);
        assert(contract.sources().len() == 0, 'Deletion failed');
    }

    #[test]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_delete_source_revert_not_registered() {
        let contract = setup();
        let address = contract_address_try_from_felt252(1).unwrap();
        contract.delete_source(address: address);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_decompose() {
        let contract = setup();
    }

    #[test]
    #[available_gas(10000000)]
    fn test_compose() {
        let contract = setup();
    }
}
