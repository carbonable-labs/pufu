use starknet::ContractAddress;

#[starknet::interface]
trait IPufu<TContractState> {
    fn component_address(self: @TContractState, sk: felt252) -> ContractAddress;
    fn components(self: @TContractState) -> Array<felt252>;
    fn register_component(ref self: TContractState, sk: felt252, name: felt252, symbol: felt252);
    fn delete_component(ref self: TContractState, sk: felt252);
    fn sources(self: @TContractState) -> Array<ContractAddress>;
    fn source_components(self: @TContractState, address: ContractAddress) -> Array<felt252>;
    fn register_source(
        ref self: TContractState, address: ContractAddress, components: Array<felt252>
    );
    fn delete_source(ref self: TContractState, address: ContractAddress);
    fn compose(ref self: TContractState, address: ContractAddress, token_id: u256);
    fn decompose(ref self: TContractState, address: ContractAddress, token_id: u256);
    fn register_token(
        ref self: TContractState,
        address: ContractAddress,
        token_id: u256,
        components: Array<felt252>
    );
    fn delete_token(ref self: TContractState, address: ContractAddress, token_id: u256);
    fn tokens(self: @TContractState, address: ContractAddress) -> Array<u256>;
    fn token_components(
        self: @TContractState, address: ContractAddress, token_id: u256
    ) -> Array<felt252>;
}
