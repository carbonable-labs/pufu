#[starknet::contract]
mod mock {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::super::super::super::interfaces::erc721::{IERC721};
    use traits::TryInto;
    use option::OptionTrait;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[external(v0)]
    impl ERC721 of IERC721<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            starknet::contract_address_const::<'ADMIN'>()
        }
        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {}
    }
}
