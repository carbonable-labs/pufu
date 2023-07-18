use starknet::ContractAddress;

#[starknet::interface]
trait IERC721<TContractState> {
     fn owner_of(self : @TContractState ,token_id: u256) -> ContractAddress;
}
