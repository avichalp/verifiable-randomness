const {ethers} = require("hardhat");
const asserts = require('assert');
const { use } = require("chai");


async function assertRevert(tx, expectedMessage) {
    let error;
  
    try {
      await (await tx).wait();
    } catch (err) {
      error = err;
    }
  
    if (!error) {
      throw new Error('Transaction was expected to revert, but it did not');
    } else if (expectedMessage) {
      const receivedMessage = error.toString();
  
      if (!receivedMessage.includes(expectedMessage)) {
        throw new Error(
          `Transaction was expected to revert with "${expectedMessage}", but reverted with "${receivedMessage}"`
        );
      }
    }
  }


describe('Lottery', () => {
    let Lottery;
    let Link;
    let VRFCoordinator;
    let V3Aggregator

    let users;
    let owner, user;

    let tx;

    let fee = "100000000000000000";
    let keyHash = "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

    beforeEach('identify signers', async () => {
        users = await ethers.getSigners();
        [owner, user] = users;
    });

    beforeEach('deploy contract', async () => {
        let factory = await ethers.getContractFactory('LinkToken');
        Link = await factory.deploy();

        factory = await ethers.getContractFactory('VRFCoordinatorMock');
        VRFCoordinator = await factory.deploy(Link.address);

        factory = await ethers.getContractFactory('MockV3Aggregator');
        V3Aggregator = await factory.deploy(8, "100000000000000000");

        factory = await ethers.getContractFactory('Lottery');
        Lottery = await factory.deploy(
            V3Aggregator.address,
            VRFCoordinator.address,
            Link.address,
            fee,
            keyHash,
        );

        // fund lottery contract with LINK (ERC20)
        await Link.transfer(Lottery.address, "100000000000000000");
        

    });

    describe("when user opens a lottery", () => {
        it('reverts if user is not owner', async () => {            
            await assertRevert(
                Lottery.connect(user).startLottery(),
                'Ownable: caller is not the owner'
              ); 
        });

        it('reverts if Lottery state was not in CLOSED state', async () => {
            await Lottery.startLottery();
            await assertRevert(
                Lottery.startLottery(),
                "can't start the lottery yet"
              );
            // tx = await Lottery.endLottery();
            // const { events } = await tx.wait();      
            // const requestedRandomnessEvent = events.filter((e) => e.event === "RequestedRandomness")[0];
            // const requestId = requestedRandomnessEvent.args[0];
            // console.log("request id", requestId);
            // tx = await VRFCoordinator.callBackWithRandomness(requestId, 777, Lottery.address);
            // console.log(await tx.wait());
            // console.log("state", await Lottery.lottery_state());


        });

        it('reverts when user is not the owner and lottery is already closed', async () => {
            await Lottery.startLottery();
            // non owner tries to open and already opened lottery
            await assertRevert(
                Lottery.connect(user).startLottery(),
                "Ownable: caller is not the owner"
              );
        });

        it('state becomes OPEN when user is owner and earlier state was closed', async () => {
            await Lottery.startLottery();
            asserts.equal(await Lottery.lottery_state(), 0);
        });
    });

    describe("when user tries to enter a lottery", () => {
        it('reverts when user enter with value less than required amount', async () => {            
            tx = await Lottery.startLottery();
            const entranceFee = await Lottery.getEntranceFee();
            await assertRevert(
                Lottery.enter({value: entranceFee.sub(1)}),
                "Not enough ETH"
            );            
        });

        it('reverts when user enter with in a CLOSED lottery', async () => {
            const entranceFee = await Lottery.getEntranceFee();
            await assertRevert(
                Lottery.enter({value: entranceFee.add(1)}),
                "Can't enter the new lottery yet!"
            );  
        });
    });

    describe("when owner ends a lottery that has not been started", () => {

        it('reverts', async () => {
            console.log("hello", Link.address);
            await assertRevert(
                Lottery.endLottery(),
                'Lottery is not open yet'
              ); 
        })

    });
});