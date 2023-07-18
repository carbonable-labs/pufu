use starknet::ContractAddress;

#[starknet::interface]
trait IComde<TContractState> {
    fn components(self: @TContractState) -> Array<felt252>;
    fn register_component(ref self: TContractState, sk: felt252, name: felt252, symbol: felt252);
    fn delete_component(ref self: TContractState, sk: felt252);
    fn sources(self: @TContractState) -> Array<ContractAddress>;
    fn source_components(self: @TContractState, address: ContractAddress) -> Array<felt252>;
    fn register_source(
        ref self: TContractState, address: ContractAddress, components: Array<felt252>
    );
    fn delete_source(ref self: TContractState, address: ContractAddress);
    fn compose(self: @TContractState, address: ContractAddress);
    fn decompose(self: @TContractState, address: ContractAddress, token_id: u256);
}
