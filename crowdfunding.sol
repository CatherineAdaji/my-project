// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IERC20 {

    function transfer(address, uint) external returns (bool);
 
    function transferFrom(address, address, uint) external returns (bool);

}
 
contract CrowdFund {

    event Launch(

        uint id,

        address indexed creator,

        uint goal,

        uint32 startAt,

        uint32 endAt

    );

    event Cancel(uint id);

    event Pledge(uint indexed id, address indexed caller, uint amount);

    event Unpledge(uint indexed id, address indexed caller, uint amount);

    event Claim(uint id);

    event Refund(uint id, address indexed caller, uint amount);
 
    struct Campaign {

        // Creator of campaign

        address creator;

        // Amount of tokens to raise

        uint goal;

        // Total amount pledged

        uint pledged;

        // Timestamp of start of campaign

        uint32 startAt;

        // Timestamp of end of campaign

        uint32 endAt;

        // True if goal was reached and creator has claimed the tokens.

        bool claimed;

    }
 //the standard token needed for the contributions
    IERC20 public immutable token;

    // Total count of campaigns created.

    // It is also used to generate id for new campaigns.

    uint public count;

    // Mapping from id to Campaign

    mapping(uint => Campaign) public campaigns;

    // Mapping from campaign id => pledger => amount pledged

    mapping(uint => mapping(address => uint)) public pledgedAmount;
 //address for contributions to be paid into
    constructor(address _token) {

        token = IERC20(_token);

    }
 //we need a function to put launch the campaign into action
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {

        
        require(_startAt >= block.timestamp, "start at < now");

        require(_endAt >= _startAt, "end at < start at");

        require(_endAt <= block.timestamp + 90 days, "end at > max duration");
 
        count += 1;

        campaigns[count] = Campaign({

            creator: msg.sender,

            goal: _goal,

            pledged: 0,

            startAt: _startAt,

            endAt: _endAt,

            claimed: false

        });
 
        emit Launch(count, msg.sender, _goal, _startAt, _endAt);

    }
 
    function cancel(uint _id) external {

        Campaign memory campaign = campaigns[_id];
//name of struct,campaign name=mapping
        require(campaign.creator == msg.sender, "not creator");

        require(block.timestamp < campaign.startAt, "started");
 
        delete campaigns[_id];

        emit Cancel(_id);

    }
 //function where people can contribute their money to a campaign
    function pledge(uint _id, uint _amount) external {
//struct ,name of campaign=name of mapping[_id]
        Campaign storage campaign = campaigns[_id];

//This requires that pledges be made only after campaign has started
        require(block.timestamp >= campaign.startAt, "not started");
//this requires pledges to be made before the stated end time
        require(block.timestamp <= campaign.endAt, "ended");
 //this offers the opportunity to add amount to the campaign pledges
        campaign.pledged += _amount;
//This increases the campaign address with a pledged amount
        pledgedAmount[_id][msg.sender] += _amount;

//this allows money to be drawn from the pledger's account by the creator
        token.transferFrom(msg.sender, address(this), _amount);
 
 //communicates with the frrontend on the pledges made
        emit Pledge(_id, msg.sender, _amount);

    }
 //this allows the pledger retract his pledge
    function unpledge(uint _id, uint _amount) external {
//helps us retrieve the particular campaign in question
        Campaign storage campaign = campaigns[_id];
//this requires that retraction be done before the end of the campaign
        require(block.timestamp <= campaign.endAt, "ended");
 //this reduces the amount formerly pledged from the campaign
        campaign.pledged -= _amount;
//this reduces the amount formerly pledged from the msg.sender's address
        pledgedAmount[_id][msg.sender] -= _amount;
//this allows the creator to transfer the pledged amount back to the pledger
        token.transfer(msg.sender, _amount);
 //communicates the unplede event to the frontend
        emit Unpledge(_id, msg.sender, _amount);

    }
 //function for claiming the campaign money at the end of the campaign
    function claim(uint _id) external {
//struct, name of campaign=name of mapping
        Campaign storage campaign = campaigns[_id];
//only creator can claim
        require(campaign.creator == msg.sender, "not creator");
//claim can only happen after the campaign has ended
        require(block.timestamp > campaign.endAt, "not ended");
//the pledged amount must be greater than  or equal to the goal of the campaign
        require(campaign.pledged >= campaign.goal, "pledged < goal");
//you can only claim if it has not been claimed,else say "claimed"
        require(!campaign.claimed, "claimed");
 //this indicates true when the pldged amount has been successfully claimed
        campaign.claimed = true;
//to transfer the money pledged you need the creator and amount pledged
        token.transfer(campaign.creator, campaign.pledged);
 //communicates the claiming event to the frontend
        emit Claim(_id);

    }
 //function to refund money when we did'nt meet up with our goal
    function refund(uint _id) external {

        Campaign memory campaign = campaigns[_id];
//refunds can only be done when campign has ended
        require(block.timestamp > campaign.endAt, "not ended");
//requires that pledgedamount must be less than the goal
        require(campaign.pledged < campaign.goal, "pledged >= goal");
 //this allows and saves the amount 'bal' to be refunded back to pledgers 
        uint bal = pledgedAmount[_id][msg.sender];
//reverts plegers amount to zero, nullifies the pledger's money to zero
        pledgedAmount[_id][msg.sender] = 0;
// allows for the transfer of the refund amount
        token.transfer(msg.sender, bal);
 //communicates refund to fontend
        emit Refund(_id, msg.sender, bal);

    }

}

