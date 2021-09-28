const Web3 = require('web3')
const { MerkleTree } = require('merkletreejs')
const keccak = require('keccak')
const abi = require('./abi.json')
const kk = (x) => keccak('keccak256').update(x).digest().toString('hex')
const proofer = {
    proofs: {}
};
const web3 = new Web3('https://rinkeby.infura.io/v3/fad40c6991a64c0db19de9420e2ace3f')
const uts = new web3.eth.Contract(abi, '0x989CD2a23E7e5547a8acC884A84FA75fE95A9b0e');
(async () => {
    const addresses = ['0xb9942a2b7ab89c1c3a7330c664897d4ea9ae2a88',
    '0x673394895b3654e81aeb229412c2a8cf7955d7b4',
    '0x058fdbe3c0f5dd1e93e72fc3120e3143a98c9c35',
    '0x45402842edb8f2ea42b8886dac45bceee265223d',
    '0xcd6ac1438ca44b8bed81713d5c24934a34cb0dc9']
let leaves = addresses.map(e=>uts.methods.getLeaf(e).call())
leaves = await Promise.all(leaves)
leaves = leaves.map(e=>e.slice(2))
console.log(leaves)
const tree = new MerkleTree(leaves, kk)
const root = tree.getRoot().toString('hex')
proofer.root = '0x'+root
for (let leafIndex in leaves) {
    const leaf = leaves[leafIndex]
    const proof = tree.getHexProof(leaf)
    address = addresses[leafIndex]
    proofer.proofs[address] = {
        index: parseInt(leafIndex),
        proof
    }
}

console.log(JSON.stringify(proofer))
})()



