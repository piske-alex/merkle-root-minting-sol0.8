const { MerkleTree } = require('merkletreejs')
const keccak = require('keccak')
const kk = (x) => keccak('keccak256').update(x).digest().toString('hex')

const leaves = [ '0xb9942a2b7ab89c1c3a7330c664897d4ea9ae2a88',
'0x673394895b3654e81aeb229412c2a8cf7955d7b4',
'0x058fdbe3c0f5dd1e93e72fc3120e3143a98c9c35',
'0x45402842edb8f2ea42b8886dac45bceee265223d',
'0xcd6ac1438ca44b8bed81713d5c24934a34cb0dc9'].map(kk)
const tree = new MerkleTree(leaves, kk)
const root = tree.getRoot().toString('hex')
console.log('merkle root', root)
const leaf = kk('0x673394895b3654e81aeb229412c2a8cf7955d7b4')
const proof = tree.getProof(leaf)
console.log(JSON.stringify(tree.getHexProof(leaf)))
console.log(tree.verify(proof, leaf, root)) // true
