#[cfg(test)]
mod test {
    use array::ArrayTrait;
    use core::result::ResultTrait;
    use core::traits::Into;
    use option::OptionTrait;
    use starknet::syscalls::deploy_syscall;
    use starknet::get_contract_address;
    use starknet::ContractAddress;
    use starknet::testing::set_contract_address;
    use traits::TryInto;

    use super::super::super::pufu::pufu;
    use super::super::super::interfaces::pufu::{IPufuDispatcher, IPufuDispatcherTrait};
    use super::super::super::erc20::erc20;
    use super::super::super::interfaces::erc721::{
        IERC721Dispatcher, IERC721DispatcherTrait, IERC721MinterDispatcher, IERC721MinterDispatcherTrait
    };
    use super::super::super::tests::mocks::erc721::erc721;
    use super::super::super::interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

    const TOKEN_ONE: u256 = 1;
    const TOKEN_TWO: u256 = 2;

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
        calldata.append('NAME');
        calldata.append('SYMBOL');
        let (address, _) = deploy_syscall(
            erc721::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        IERC721Dispatcher { contract_address: address }
    }

    fn setup() -> (IPufuDispatcher, IERC721Dispatcher, ContractAddress, ContractAddress) {
        let admin = starknet::contract_address_const::<'ADMIN'>();
        let anyone = starknet::contract_address_const::<'ANYONE'>();
        set_contract_address(admin);
        // Deploy ERC721 and mint tokens to anyone
        let erc721 = deploy_erc721();
        let erc721_minter = IERC721MinterDispatcher { contract_address: erc721.contract_address };
        erc721_minter.mint(to: anyone, token_id: TOKEN_ONE);
        erc721_minter.mint(to: anyone, token_id: TOKEN_TWO);
        // Deploy Pufu and register source, generic components and specific components
        let pufu = deploy_pufu();
        let generic_component = 'GENERIC_COMPONENT';
        let specific_component = 'SPECIFIC_COMPONENT';
        pufu.register_component(generic_component, 'GENERIC_NAME', 'GENERIC_SYMBOL');
        pufu.register_component(specific_component, 'SPECIFIC_NAME', 'SPECIFIC_SYMBOL');
        let mut source_components: Array<felt252> = ArrayTrait::new();
        source_components.append(generic_component);
        pufu.register_source(erc721.contract_address, source_components);
        let mut token_components: Array<felt252> = ArrayTrait::new();
        token_components.append(specific_component);
        pufu.register_token(erc721.contract_address, TOKEN_ONE, token_components);
        (pufu, erc721, admin, anyone)
    }

    #[test]
    #[available_gas(100000000)]
    fn test_decompose_then_compose_one_token() {
        let (pufu, erc721, admin, anyone) = setup();
        // Anyone decomposes token one
        set_contract_address(anyone);
        erc721.approve(pufu.contract_address, TOKEN_ONE);
        pufu.decompose(erc721.contract_address, TOKEN_ONE);
        // Anyone composes token one
        pufu.compose(erc721.contract_address, TOKEN_ONE);
    }

    #[test]
    #[available_gas(100000000)]
    fn test_decompose_then_compose_two_tokens() {
        let (pufu, erc721, admin, anyone) = setup();
        // Anyone decomposes token one
        set_contract_address(anyone);
        erc721.approve(pufu.contract_address, TOKEN_ONE);
        pufu.decompose(erc721.contract_address, TOKEN_ONE);
        // Anyone decomposes token two
        set_contract_address(anyone);
        erc721.approve(pufu.contract_address, TOKEN_TWO);
        pufu.decompose(erc721.contract_address, TOKEN_TWO);
        // Anyone composes token one
        pufu.compose(erc721.contract_address, TOKEN_ONE);
        // Anyone composes token two
        pufu.compose(erc721.contract_address, TOKEN_TWO);
    }
}
