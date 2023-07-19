#[starknet::contract]
mod pufu {
    use zeroable::Zeroable;
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use array::{Array, ArrayTrait};
    use poseidon::poseidon_hash_span;
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::get_caller_address;
    use starknet::deploy_syscall;
    use alexandria::storage::list::{List, ListTrait};
    use super::super::interfaces::pufu::IPufu;
    use starknet::get_contract_address;
    use super::super::interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use super::super::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use alexandria::math::math;
    use debug::PrintTrait;

    const TOKEN_QTY: u128 = 1;

    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _class_hash_erc20: ClassHash,
        _sources: List<ContractAddress>,
        _source_components: LegacyMap<ContractAddress, List<felt252>>,
        _token_components: LegacyMap<felt252, List<felt252>>,
        _components: List<felt252>,
        _component_addresses: LegacyMap::<felt252, ContractAddress>,
        _token_ids: LegacyMap<ContractAddress, List<u256>>,
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
    }

    #[generate_trait]
    #[external(v0)]
    impl Assert of IAssert {
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self._owner.read();
            assert(caller == owner, 'Caller is not owner');
        }
    }

    #[external(v0)]
    impl Comde of IPufu<ContractState> {
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

            // [Check] Check total supply is zero
            let erc20 = IERC20Dispatcher { contract_address: address };
            assert(erc20.total_supply() == 0, 'Total supply is not null');

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

            // [Check] No decomposition on going
            let token_ids = self._token_ids.read(address);
            assert(token_ids.len() == 0, 'Decomposition still exists');

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

        fn tokens(self: @ContractState, address: ContractAddress) -> Array<u256> {
            self._token_ids.read(address).array()
        }

        fn token_components(
            self: @ContractState, address: ContractAddress, token_id: u256
        ) -> Array<felt252> {
            let hash = self._token_components_hash(address, token_id);
            self._token_components.read(hash).array()
        }

        fn register_token(
            ref self: ContractState,
            address: ContractAddress,
            token_id: u256,
            components: Array<felt252>
        ) {
            // [Check] Caller is owner
            self.assert_only_owner();

            // [Check] Token not already registered
            let hash = self._token_components_hash(address, token_id);
            let mut token_components = self._token_components.read(hash);
            assert(token_components.len() == 0, 'Token already registered');

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
                token_components.append(component);
                index += 1;
            };
        }

        fn delete_token(ref self: ContractState, address: ContractAddress, token_id: u256) {
            // [Check] Caller is owner
            self.assert_only_owner();

            // [Check] Token already registered
            let hash = self._token_components_hash(address, token_id);
            let mut token_components = self._token_components.read(hash);
            assert(token_components.len() != 0, 'Token not registered');

            // [Check] The token is not decomposed
            let erc721 = IERC721Dispatcher { contract_address: address };
            let owner = erc721.owner_of(token_id);
            let contract = get_contract_address();
            assert(owner != contract, 'Token is decomposed');

            // [Effect] Delete components
            let mut index = token_components.len() - 1;
            loop {
                if index == 0 {
                    break ();
                }
                token_components.pop_front();
            };
        }

        fn compose(self: @ContractState, address: ContractAddress, token_id: u256) {
            let mut source_components = self._source_components.read(address);

            // [Compute] Token components (could be empty)
            let hash = self._token_components_hash(address, token_id);
            let mut token_components = self._token_components.read(hash);

            // [Check] Source or token component has been registered
            assert(
                source_components.len() != 0 || token_components.len() != 0,
                'No component registered'
            );

            // [Check] Contract has at least 1 token
            let erc721 = IERC721Dispatcher { contract_address: address };
            let contract = get_contract_address();
            let mut token_ids = self._token_ids.read(erc721.contract_address);
            assert(token_ids.len() > 0, 'No token to redeem');

            // [Interaction] Generic composition
            let caller = get_caller_address();
            let mut index = 0;
            loop {
                if index == source_components.len() {
                    break ();
                }
                // [Check] Component balance of caller
                let sk = source_components.get(index).expect('index out of bounds');
                let erc20_address = self._component_addresses.read(sk);
                let erc20 = IERC20Dispatcher { contract_address: erc20_address };
                let balance = erc20.balance_of(caller);
                let decimals = erc20.decimals();
                let minimum_balance = TOKEN_QTY * math::pow(10, decimals.into());
                assert(balance >= minimum_balance.into(), 'Insufficient balance');

                // [Interaction] Burn ERC20 tokens
                erc20.burn(caller, minimum_balance.into());
                index += 1;
            };

            // [Interaction] Specific composition
            let mut index = 0;
            loop {
                if index == token_components.len() {
                    break ();
                }
                let sk = token_components.get(index).expect('index out of bounds');
                let erc20_address = self._component_addresses.read(sk);
                let erc20 = IERC20Dispatcher { contract_address: erc20_address };
                let balance = erc20.balance_of(caller);
                let decimals = erc20.decimals();
                let minimum_balance = TOKEN_QTY * math::pow(10, decimals.into());
                assert(balance >= minimum_balance.into(), 'Insufficient balance');

                // [Interaction] Burn ERC20 tokens
                erc20.burn(caller, minimum_balance.into());
                index += 1;
            };

            // [Interaction] Redeem ERC721 token
            erc721.transfer_from(contract, caller, token_id);
        }

        fn decompose(self: @ContractState, address: ContractAddress, token_id: u256) {
            //[Check] caller is the ERC721 owner
            let caller = get_caller_address();
            let erc721_contract = IERC721Dispatcher { contract_address: address };
            let owner = erc721_contract.owner_of(token_id);
            assert(caller == owner, 'Only owner can decompose');

            let mut source_components = self._source_components.read(address);

            // [Compute] Token components (could be empty)
            let mut inputs: Array<felt252> = ArrayTrait::new();
            inputs.append(address.into());
            inputs.append(token_id.low.into());
            inputs.append(token_id.high.into());
            let hash = poseidon_hash_span(inputs.span());
            let mut token_components = self._token_components.read(hash);

            // [Check] Source or token component has been registered
            assert(
                source_components.len() != 0 || token_components.len() != 0,
                'No component registered'
            );

            // [Effect] Store the token_id
            let mut token_ids = self._token_ids.read(address);
            token_ids.append(token_id);

            // [Interaction] Transfer token_id
            let to = get_contract_address();
            erc721_contract.transfer_from(from: caller, to: to, token_id: token_id);

            // [Interaction] Generic decomposition
            let mut index = 0;
            loop {
                if index == source_components.len() {
                    break ();
                }
                // [Compute] Quantity to _mint
                let component = source_components[index];
                let erc20_address = self._component_addresses.read(component);
                let erc20 = IERC20Dispatcher { contract_address: erc20_address };
                let decimals: u128 = erc20.decimals().into();
                let qty = TOKEN_QTY * math::pow(10, decimals);
                // [Interaction] Mint component
                erc20.mint(caller, qty.into());
                index += 1;
            };

            // [Interaction] Specific decomposition
            let mut index = 0;
            loop {
                if index == token_components.len() {
                    break ();
                }
                // [Compute] Quantity to mint
                let component = token_components[index];
                let erc20_address = self._component_addresses.read(component);
                let erc20 = IERC20Dispatcher { contract_address: erc20_address };
                let decimals: u128 = erc20.decimals().into();
                let qty = TOKEN_QTY * math::pow(10, decimals);
                // [Interaction] Mint component
                erc20.mint(caller, qty.into());
                index += 1;
            };
        }
    }

    #[generate_trait]
    impl Internal of IInternal {
        fn _token_components_hash(
            self: @ContractState, address: ContractAddress, token_id: u256
        ) -> felt252 {
            let mut inputs: Array<felt252> = ArrayTrait::new();
            inputs.append(address.into());
            inputs.append(token_id.low.into());
            inputs.append(token_id.high.into());
            poseidon_hash_span(inputs.span())
        }
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
    use starknet::ContractAddress;
    use starknet::testing::set_contract_address;
    use traits::TryInto;
    use alexandria::math::math;
    use debug::print;
    use debug::PrintTrait;
    use super::pufu;
    use super::super::interfaces::pufu::{IPufuDispatcher, IPufuDispatcherTrait};
    use super::super::erc20::erc20;
    use super::super::interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use super::super::tests::mocks::erc721::mock;
    use super::super::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    fn deploy_pufu() -> IPufuDispatcher {
        let mut calldata = Default::default();
        calldata.append(erc20::TEST_CLASS_HASH);
        calldata.append(get_contract_address().into());
        let (address, _) = deploy_syscall(
            pufu::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        IPufuDispatcher { contract_address: address }
    }

    fn deploy_erc721() -> IERC721Dispatcher {
        let mut calldata = Default::default();
        let (address, _) = deploy_syscall(
            mock::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        IERC721Dispatcher { contract_address: address }
    }

    fn setup() -> (IPufuDispatcher, IERC721Dispatcher, ContractAddress) {
        let admin = starknet::contract_address_const::<'ADMIN'>();
        set_contract_address(admin);
        (deploy_pufu(), deploy_erc721(), admin)
    }

    #[test]
    #[available_gas(10000000)]
    fn test_initialization() {
        let (contract, _, _) = setup();
        assert(contract.components().len() == 0, 'Initialization failed');
        let address = contract.component_address(sk: 'SK');
        assert(address == Zeroable::zero(), 'Wrong address');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_register_component() {
        let (contract, _, _) = setup();
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
        let (contract, _, _) = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_delete_component() {
        let (contract, _, _) = setup();
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
        let (contract, _, _) = setup();
        let sk = 'SK';
        contract.delete_component(sk: sk);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_register_source() {
        let (contract, _, _) = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        let address = starknet::contract_address_const::<'ADDRESS'>();
        contract.register_source(address: address, components: components);
        assert(contract.sources().len() == 1, 'Registration failed');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_register_token() {
        let (contract, erc721, admin) = setup();
        let sk = 'SK';
        let token_id = 1_u256;
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_token(erc721.contract_address, token_id, components);
    }

    #[test]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_register_token_revert_already_registered() {
        let (contract, erc721, admin) = setup();
        let sk = 'SK';
        let token_id = 1_u256;
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_token(erc721.contract_address, token_id, components);
        let components = contract.components();
        contract.register_token(erc721.contract_address, token_id, components);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_delete_token() {
        let (contract, erc721, admin) = setup();
        let sk = 'SK';
        let token_id = 1_u256;
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_token(erc721.contract_address, token_id, components);
        contract.delete_token(erc721.contract_address, token_id)
    }

    #[test]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_register_source_revert_already_registered() {
        let (contract, _, _) = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        let address = starknet::contract_address_const::<'ADDRESS'>();
        contract.register_source(address: address, components: components);
        let components = contract.components();
        contract.register_source(address: address, components: components);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_delete_source() {
        let (contract, _, _) = setup();
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        let address = starknet::contract_address_const::<'ADDRESS'>();
        contract.register_source(address: address, components: components);
        contract.delete_source(address: address);
        assert(contract.sources().len() == 0, 'Deletion failed');
    }

    #[test]
    #[should_panic]
    #[available_gas(10000000)]
    fn test_delete_source_revert_not_registered() {
        let (contract, _, _) = setup();
        let address = starknet::contract_address_const::<'ADDRESS'>();
        contract.delete_source(address: address);
    }

    #[test]
    #[available_gas(10000000)]
    fn test_decompose() {
        let (contract, erc721, admin) = setup();
        let sk = 'SK';
        let token_id = 1_u256;
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_source(address: erc721.contract_address, components: components);
        contract.decompose(erc721.contract_address, token_id);
        let erc20_address = contract.component_address(sk: sk);
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        // [Check] ERC20 new balance
        let decimals: u128 = erc20.decimals().into();
        let qty = pufu::TOKEN_QTY * math::pow(10, decimals);
        assert(erc20.balance_of(admin) == qty.into(), 'Wrong balance');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_compose() {
        let (contract, erc721, admin) = setup();
        let sk = 'SK';
        let token_id = 1_u256;
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_source(address: erc721.contract_address, components: components);
        contract.decompose(erc721.contract_address, token_id);
        contract.compose(erc721.contract_address, token_id);
        // [Check] ERC20 new balance
        let erc20_address = contract.component_address(sk: sk);
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        assert(erc20.balance_of(admin) == 0, 'Wrong balance');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_specific_decompose() {
        let (contract, erc721, admin) = setup();
        let token_id = 1_u256;
        //[Effect] register generic component
        let gk = 'GK';
        contract.register_component(sk: gk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_source(address: erc721.contract_address, components: components);
        //[Effect] register specific component
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        //[Effect] create specific component
        let mut specific_components: Array<felt252> = ArrayTrait::new();
        specific_components.append(sk);
        //[Effect] register token
        contract.register_token(erc721.contract_address, token_id, specific_components);
        //[Interaction] decompose
        contract.decompose(erc721.contract_address, token_id);
        //[Check] generic erc20 new balance
        let erc20_address = contract.component_address(sk: gk);
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        let decimals: u128 = erc20.decimals().into();
        let qty = pufu::TOKEN_QTY * math::pow(10, decimals);
        assert(erc20.balance_of(admin) == qty.into(), 'Wrong generic balance');
        //[Check] specific erc20 new balance
        let erc20_address = contract.component_address(sk: sk);
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        let decimals: u128 = erc20.decimals().into();
        let qty = pufu::TOKEN_QTY * math::pow(10, decimals);
        assert(erc20.balance_of(admin) == qty.into(), 'Wrong specific balance');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_specific_compose() {
        let (contract, erc721, admin) = setup();
        let token_id = 1_u256;
        //[Effect] register generic component
        let gk = 'GK';
        contract.register_component(sk: gk, name: 'NAME', symbol: 'SYMBOL');
        let components = contract.components();
        contract.register_source(address: erc721.contract_address, components: components);
        //[Effect] register specific component
        let sk = 'SK';
        contract.register_component(sk: sk, name: 'NAME', symbol: 'SYMBOL');
        //[Effect] create specific component
        let mut specific_components: Array<felt252> = ArrayTrait::new();
        specific_components.append(sk);
        //[Effect] register token
        contract.register_token(erc721.contract_address, token_id, specific_components);
        //[Interaction] decompose
        contract.decompose(erc721.contract_address, token_id);
        //[Interaction] compose
        contract.compose(erc721.contract_address, token_id);
        //[Check] generic erc20 new balance ==0
        let erc20_address = contract.component_address(sk: gk);
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        let decimals: u128 = erc20.decimals().into();
        let qty = pufu::TOKEN_QTY * math::pow(10, decimals);
        assert(erc20.balance_of(admin) == 0, 'Wrong generic balance');
        //[Check] specific erc20 new balance ==0
        let erc20_address = contract.component_address(sk: sk);
        let erc20 = IERC20Dispatcher { contract_address: erc20_address };
        let decimals: u128 = erc20.decimals().into();
        let qty = pufu::TOKEN_QTY * math::pow(10, decimals);
        assert(erc20.balance_of(admin) == 0, 'Wrong specific balance');
    }
}
