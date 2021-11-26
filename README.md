# Verifiable Randomness

**Note: This project is a learning exercise should not be used in production**

Blockchains are notoriously deterministic. Chainlink provides a source of [verifiable randomess](https://docs.chain.link/docs/chainlink-vrf/) on the blockchain.

> Chainlink VRF (Verifiable Random Function) is a provably-fair and verifiable source of randomness designed for smart contracts. Smart contract developers can use Chainlink VRF as a tamper-proof random number generator (RNG) to build reliable smart contracts for any applications which rely on unpredictable outcomes:

This project uses this Chainlink to get a random number. A user can participate in the lottery by sending a transaction to this contract with a value greater than a minimum required fee.

All the entrants are added to an array. Based on the random number provided by Chainlink, an index of the array is chosen as the winner. When the lottery ends, the winner will be transferred all the funds collected in the contract.

The Owner is a privileged user. They can start and end the lottery.

Use hardhat to run tests:

```shell
npx hardhat test
```
