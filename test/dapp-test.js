const { expect, assert } = require("chai")
const { BigNumber, providers } = require("ethers")
const { ethers, network, web3, artifacts } = require("hardhat")
const { BN, expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers');

const maxNumberAccounts = 100
let numberAccounts
let secuenceMetaData
let result
let disputeResult
let disputed
let receiverAccount
let oracleAccount
let ownerAccount
let contributions

const gasPrice = 1

const day = 24 * 60 * 60
//const oneEther = BigNumber.from(Math.pow(10, 18).toString())

const oneEther = BigNumber.from("1000000000000000000")
const oneGWei = BigNumber.from("1000000000")

const getBNPercent = (percent, number) => number.mul(BigNumber.from(percent.toString())).div(BigNumber.from("100"))

const getRandomIntInclusive = (min, max) => {
    min = Math.ceil(min)
    max = Math.floor(max)
    return Math.floor(Math.random() * (max - min + 1) + min) //The maximum is inclusive and the minimum is inclusive
}

const getPollData = async (instance, pollId) => await instance.polls(pollId)
const getPollTotalAmountContributed = async (instance, pollId) => (await getPollData(instance, pollId))[0]
const getPollDate = async (instance, pollId) => (await getPollData(instance, pollId))[2]
const isPollResolvedByOracle = async (instance, pollId) => (await getPollData(instance, pollId))[4]
const getPollOracleResult = async (instance, pollId) => (await getPollData(instance, pollId))[5]
const isPollDisputed = async (instance, pollId) => (await getPollData(instance, pollId))[6]
const isPollUltimateOracleResolved = async (instance, pollId) => (await getPollData(instance, pollId))[7]
const getPollUltimateOracleResult = async (instance, pollId) => (await getPollData(instance, pollId))[8]
const getPollReceiverId = async (instance, pollId) => (await getPollData(instance, pollId))[3]
const getPollOracleId = async (instance, pollId) => (await getPollData(instance, pollId))[1]
const getOracleData = async (instance, oracleId) => await instance.oracles(oracleId)
const getOracleResponseTime = async (instance, oracleId) => (await getOracleData(instance, oracleId))[3]

describe("Dapp", async function() {
    const deployContracts = () => {
        before(async function () {
            this.accounts = await ethers.getSigners()

            ownerAccount = this.accounts[0]

            this.AccountsStorage = await ethers.getContractFactory('AccountsStorage')
            this.accountsStorage = await this.AccountsStorage.deploy()
            this.accountsStorageInstance = await this.accountsStorage.deployed()

            this.PollRewards = await ethers.getContractFactory('PollRewards')
            this.pollRewards = await this.PollRewards.deploy(this.accountsStorageInstance.address)
            this.pollRewardsInstance = await this.pollRewards.deployed()


            this.UltimateOracle = await ethers.getContractFactory('UltimateOracle')
            this.ultimateOracle = await this.UltimateOracle.deploy(this.pollRewardsInstance.address)
            this.ultimateOracleInstance = await this.ultimateOracle.deployed()

            this.pollRewardsInstance.setUltimateOracleFee("1000000")
            this.pollRewardsInstance.setUltimateOracleAddress(this.ultimateOracleInstance.address)
        })
    }

    const createAccounts = () => {
        it("Should create an account", async function () {
            this.timeout(10000 * maxNumberAccounts)
    
            for (let _i = 0; _i < maxNumberAccounts; _i++ ) {
                await this.accountsStorageInstance.connect(this.accounts[_i]).createReceiverAccount()
            }
    
            for (let _i = 0; _i < maxNumberAccounts; _i++) {
                await expect(this.accountsStorageInstance.connect(this.accounts[_i]).createReceiverAccount()).to.be.revertedWith("Address must not have account")
            }
    
            for (let _i = 0; _i < maxNumberAccounts; _i++) {
                let id = await this.accountsStorageInstance.addressToReceiverId(this.accounts[_i].address)
                let accountAddress = await this.accountsStorageInstance.receivers(id)
    
                expect(id).to.be.equal(_i + 1, "The account was not created or is not in the first slot")
                expect(accountAddress).to.be.equal(this.accounts[_i].address, "The account should have the address of Alice")
            } 
        })
    }

    const createOracle = () => {
        it("Should create an oracle", async function () {
            oracleAccount = this.accounts[1]

            await this.accountsStorageInstance.connect(oracleAccount).createNewOracle(day, oneEther.div(BigNumber.from(10**9)))

            let oracleAddress = await this.accountsStorageInstance.connect(oracleAccount).getOracleAddress(1)
            let oracleResponseTime = await this.accountsStorageInstance.getOracleResponseTime(1)

            expect(oracleAddress).to.be.equal(oracleAccount.address, "The oracle address must match")
            expect(oracleResponseTime).to.be.equal(day, "The oracle response time must match")
        }
    )}

    const createPollAndContribute = pollId => {
        it("Should create a poll", async function () {
            this.timeout(10000 * numberAccounts)

            receiverAccount = this.accounts[2]
            const receiverId = await this.accountsStorageInstance.addressToReceiverId(receiverAccount.address)

            let dateLimit = await time.latest()
            dateLimit = dateLimit.toNumber() + day        
        
            let contribution = oneGWei.mul(getRandomIntInclusive(1, 100000000000))
            contributions.push(contribution)

            await this.pollRewardsInstance.connect(this.accounts[3]).createPoll(receiverId, dateLimit, 1, 'QmYDAmHsFu5oWsJU21esKnN4ZRyE8txJNvrZxvxXLymC2L', {value: contribution.toHexString()})

            expect(await getPollTotalAmountContributed(this.pollRewardsInstance, pollId)).to.be.equal(contributions[0], "The total amount stored in the poll must be equal to the amount contributed")
            expect(await ethers.provider.getBalance(this.pollRewardsInstance.address)).to.be.equal(contributions[0], "The total amount stored in the contract must be equal to the amount contributed")
        
            let pollDate = await getPollDate(this.pollRewardsInstance, pollId)
            let pollResolved = await isPollResolvedByOracle(this.pollRewardsInstance, pollId)
            let pollReceiverId = await getPollReceiverId(this.pollRewardsInstance, pollId)
            let pollOracleId = await getPollOracleId(this.pollRewardsInstance, pollId)
            
            expect(pollDate).to.be.equal(dateLimit, "The date limit must be the given in the creation")
            expect(pollResolved).to.be.false
            expect(pollReceiverId).to.be.equal(3, "The poll receiver must be the correct")
            expect(pollOracleId).to.be.equal(1, "The oracle id must match")

            for (let _i = 4; _i < numberAccounts; _i++) {
                contribution = oneGWei.mul(getRandomIntInclusive(1, 100000000000))
                contributions.push(contribution)
                await this.pollRewardsInstance.connect(this.accounts[_i]).contribute(0, {value: contribution.toHexString()})
            }

            let totalAmountContributed = BigNumber.from("0")

            for (let element of contributions) {
                totalAmountContributed = totalAmountContributed.add(element)
            }
            
            expect(await getPollTotalAmountContributed(this.pollRewardsInstance, pollId)).to.be.equal(totalAmountContributed, "The total amount stored in the poll must be equal to the amount contributed")
            expect(await ethers.provider.getBalance(this.pollRewardsInstance.address)).to.be.equal(totalAmountContributed, "The total amount stored in the contract must be equal to the amount contributed")

            await time.increase(day)
        })
    }

    const resolveCurrentPoll = (pollId, result) => {
        it ("Should resove the poll", async function () {
            await this.pollRewardsInstance.connect(oracleAccount).resolvePoll(result, pollId)
        })
    }

    const openDispute = (pollId) => {
        it ("Should generate dispute", async function () {
            const ultimateOraclePreviousBalance = await ethers.provider.getBalance(this.ultimateOracleInstance.address)

            await this.pollRewardsInstance.generateDispute(pollId, {value: 1000000})

            const ultimateOracleNewBalance = await ethers.provider.getBalance(this.ultimateOracleInstance.address)

            expect(ultimateOracleNewBalance.sub(ultimateOraclePreviousBalance)).to.be.equal(BigNumber.from("1000000"))
        })
    }

    const closeDispute = (pollId, result) => {
        it ("Should close the dispute", async function () {
            await this.ultimateOracleInstance.closeDispute(pollId, result)
        })
    }

    const claimRewards = (pollId) => {
        it ("Should claim rewards", async function () {
            const oracleId = await getPollOracleId(this.pollRewardsInstance, pollId)
            const responseTime = await getOracleResponseTime(this.accountsStorageInstance, oracleId)

            await time.increase(day) 
            await time.increase(responseTime)

            const pollResolved = await isPollResolvedByOracle(this.pollRewardsInstance, pollId)
            const pollResult = await getPollOracleResult(this.pollRewardsInstance, pollId)
            const pollDisputed = await isPollDisputed(this.pollRewardsInstance, pollId)
            const pollDisputedResult = await getPollUltimateOracleResult(this.pollRewardsInstance, pollId)

            if (pollResolved) {
                if (pollDisputed) {
                    if (pollDisputedResult) {
                        if (pollDisputedResult == pollResult) {
                            await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)

                            await this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)

                            for (let _i = 3; _i < numberAccounts; _i++) {
                                await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                            } 

                            const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                            const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                            const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                        }
                        
                        else {
                            await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)

                            await expect(this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)).to.be.revertedWith("Dispute result must match result")

                            for (let _i = 3; _i < numberAccounts; _i++) {
                                await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                            } 

                            const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                            const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                            const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                        }
                    }

                    else {
                        if (pollDisputedResult == pollResult) {
                            await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)

                            await this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)

                            for (let _i = 3; _i < numberAccounts; _i++) {
                                await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                            } 

                            const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                            const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                            const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                        }

                        else {
                            await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)

                            await expect(this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)).to.be.revertedWith("Dispute result must match result")

                            for (let _i = 3; _i < numberAccounts; _i++) {
                                await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                            } 

                            const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                            const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                            const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                        }
                    }
                }

                else {
                    if (pollResult) {
                        await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)

                        await this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)

                        for (let _i = 3; _i < numberAccounts; _i++) {
                            await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                        }                 

                        const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                        const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                        const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                    }

                    else {
                        await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)                   

                        await this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)

                        for (let _i = 3; _i < numberAccounts; _i++) {
                            await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                        }       

                        const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                        const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                        const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                    }
                }
            }

            else {
                if (pollDisputed) {
                    if (pollDisputedResult) {
                        const receiverRewardTx = await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)
                        const receiverRewardReceipt = await receiverRewardTx.wait()
                        const receiverRewardTxGasUsed = receiverRewardReceipt['cumulativeGasUsed'].mul(gasPrice).mul("1000000000")

                        await expect(this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)).to.be.revertedWith("Oracle must have resolved")

                        for (let _i = 3; _i < numberAccounts; _i++) {
                            await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                        }                     

                        const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                        const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                        const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                    }

                    else {
                        const receiverRewardTx = await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)
                        const receiverRewardReceipt = await receiverRewardTx.wait()
                        const receiverRewardTxGasUsed = receiverRewardReceipt['cumulativeGasUsed'].mul(gasPrice).mul("1000000000")    

                        await expect(this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)).to.be.revertedWith("Oracle must have resolved")

                        for (let _i = 3; _i < numberAccounts; _i++) {
                            await this.dappInstance.connect(this.accounts[_i]).claimContribution(pollId)
                        }                     

                        const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                        const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                        const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                    }
                }

                else {
                    const receiverRewardTx = await this.pollRewardsInstance.connect(receiverAccount).claimReceiverReward(pollId)
                    const receiverRewardReceipt = await receiverRewardTx.wait()
                    const receiverRewardTxGasUsed = receiverRewardReceipt['cumulativeGasUsed'].mul(gasPrice).mul("1000000000")  

                    await expect(this.pollRewardsInstance.connect(oracleAccount).claimOracleReward(pollId)).to.be.revertedWith("Oracle must have resolved")
                    
                    for (let _i = 3; _i < numberAccounts; _i++) {
                        await this.pollRewardsInstance.connect(this.accounts[_i]).claimContribution(pollId)
                    }                   

                    const oracleNewBalance = await ethers.provider.getBalance(oracleAccount.address)
                    const ownerNewBalance = await ethers.provider.getBalance(ownerAccount.address)
                    const receiverNewBalance = await ethers.provider.getBalance(receiverAccount.address)
                }
            }

            expect(await ethers.provider.getBalance(this.pollRewardsInstance.address)).to.be.equal(0, "The contract balance should be empty")
        })

    }

    const runSeccuence = (pollId) => {
        numberAccounts = getRandomIntInclusive(5, maxNumberAccounts)
        secuenceMetaData = {}
        contributions = []

        createOracle()

        createPollAndContribute(pollId, "The youtuber jordi wild must bring the miguel anxo bastos to his podcast")
    
        let responds = getRandomIntInclusive(0, 1)
        console.log("responds:")
        console.log(responds)

        result = getRandomIntInclusive(0, 1)
        console.log("result:")
        console.log(result)
        
        disputed = getRandomIntInclusive(0,1)
        console.log("disputed:")
        console.log(disputed)

        disputeResult = getRandomIntInclusive(0, 1)
        console.log("dispute result:")
        console.log(disputeResult)
        
        if (responds) {
            resolveCurrentPoll(pollId, result)

            if (disputed) {
                openDispute(pollId)

                closeDispute(pollId, disputeResult)
            }
        }

        else {
            if (disputed) {
                openDispute(pollId)

                closeDispute(pollId, disputeResult)
            }
        }

        claimRewards(pollId)
    }

    deployContracts()
    
    beforeEach(async function () {
    })

    createAccounts()

    await runSeccuence(0)
})



//// El creador es el mismo que el receptor

