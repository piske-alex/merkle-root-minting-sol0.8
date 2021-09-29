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
    const addresses = ["0xB9942A2b7Ab89C1c3A7330C664897d4eA9aE2A88",
    "0x4af1e7971113C424Ba9b1222aE7b447FCa2dCAc6",
    "0xE9353b6f1FF596aa31A344464B5B5022196A3Cbe",
    "0x673394895B3654e81aEb229412c2a8Cf7955d7b4",
    "0x058fdbE3c0f5dD1e93e72fC3120E3143a98c9c35",
    "0x45402842eDB8f2eA42B8886dac45bcEEE265223D",
    "0xCd6aC1438CA44B8BED81713D5c24934A34CB0dc9"]
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
    proofer.proofs[address.toLowerCase()] = {
        index: parseInt(leafIndex),
        proof
    }
}

console.log(JSON.stringify(proofer))
})()



