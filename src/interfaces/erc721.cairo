use starknet::ContractAddress;

#[starknet::interface]
trait IERC721<TContractState> {
     fn owner_of(self : @TContractState ,token_id: u256) -> ContractAddress;
     fn transferFrom(ref self: TContractState, from: ContractAddress, to: ContractAddress, tokenId: u256);
}
