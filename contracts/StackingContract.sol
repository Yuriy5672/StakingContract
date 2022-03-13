// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./../node_modules/@openzeppelin/contracts/utils/Context.sol";
import "./../node_modules/@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
* --description contract--
*/
contract Stacking is Ownable{

    IERC20 private _token;
    uint256 private _bonus;
    uint256 private _reward;
    bool private _paused;
    uint256 _rewardVault;

    mapping(address => uint256) private _deposit;
    mapping(address => uint256) private _depositTime;
    mapping(address => uint256) private _withdrawBonuces;
    mapping(address => uint256) private _withdrawRewords;

    /*
    * --description constructor--
    */
    constructor(address tokenAddress){
        _token = IERC20(tokenAddress);
    }

    //################## Events voids ##################
    /*
    * --description event--
    */
    event Transfer(address indexed depositor, uint256 value);

    /*
    * --description event--
    */
    event AddDeposit(address indexed depositor, uint256 value);

    /*
    * --description event--
    */
    event WithdrawDeposit(address indexed depositor, uint256 value);

    /*
    * --description event--
    */
    event Workflow(address indexed depositor, uint256 value);

    /*
    * --description event--
    */
    modifier isWorkflow{
        require(_paused == false, "This action cannot be performed while the contract is paused!");
        _;
    }

    //################## User methods ##################
    /*
    * --description function--
    */
    function addDeposit(uint256 value) public isWorkflow returns(bool){
        address depositor = _msgSender();
        require(_deposit[depositor] > 0, "The address already has a deposit!");
        //require(_token.balanceOf(depositor) <= value, "Not enough funds!");
        _addDeposit(depositor, address(this), value);
        emit AddDeposit(depositor, value);
        return true;
    }

    /*
    * --description function--
    */
    function withdrawDeposit(uint256 value) public isWorkflow returns(bool){
        address depositor = _msgSender();
        require(balanceOf(depositor) >= value, "Not enough funds!");
        _withdrawDeposit(address(this), depositor, value, false);
        emit WithdrawDeposit(depositor, value);
        return true;
    }

    /*
    * --description function--
    */
    function withdrawDepositWithoutReward(uint256 value) public isWorkflow returns(bool){
        address depositor = _msgSender();
        require(_deposit[depositor] >= value, "Not enough funds!");
        _withdrawDeposit(address(this), depositor, value, true);
        emit WithdrawDeposit(depositor, value);
        return true;
    }

    /*
    * --description function--
    * balance = deposit + bonus + reward
    */
    function balanceOf(address account) public view returns(uint256){
        return _deposit[account] + _calculateBenefit(_deposit[account], _depositTime[account], _bonus, _withdrawBonuces[account]) + _calculateBenefit(_deposit[account], _depositTime[account], _reward, _withdrawRewords[account]);
    }

    /*
    * --description function--
    */
    function bonusAmount() public view returns(uint256){
        address sender = _msgSender();
        return _calculateBenefit(_deposit[sender], _depositTime[sender], _bonus, _withdrawBonuces[sender]);
    }

    /*
    * --description function--
    * вывести бонус, оставить вклад и проценты
    */
    function deductBonuses(uint256 value) public returns(bool){
        address sender = _msgSender();
        _deductBonuses(sender, value);
        _transferFrom(address(this), sender, value);
        return true;
    }

    /*
    * --description function--
    */
    function _transferFrom(address from, address to, uint256 value) private{
        _token.transferFrom(from, to, value);
    }

    function _addDeposit(address from, address to, uint256 value) private{
        _transferFrom(from, to, value);
        _deposit[from] = value;
        _depositTime[from] = block.timestamp;
    }

    function _withdrawDeposit(address from, address to, uint256 value, bool withoutReward) private{
        if(withoutReward){
            require(_deposit[to] >= value, "Not enough funds!");

            _deposit[to] -= value;
            _depositTime[to] = block.timestamp;
        }else{
            //баланс = бонус + награда + депозит
            uint256 tValue = value;

            //withdrow bonus
            uint256 bonus = _calculateBenefit(_deposit[to], _depositTime[to], _bonus, _withdrawBonuces[to]);
            if(bonus > tValue){
                _deductBonuses(to, tValue);
                tValue = 0;
            }else{
                _deductBonuses(to, tValue - _withdrawBonuces[to]);
                tValue = _withdrawBonuces[to];
            }

            if(tValue > 0){
                //withdrow reword
                uint256 reword = _calculateBenefit(_deposit[to], _depositTime[to], _reward, _withdrawRewords[to]);
                if(reword > tValue){
                    _deductRewords(to, tValue);
                    tValue = 0;
                }else{
                    _deductRewords(to, tValue - _withdrawRewords[to]);
                    tValue = _withdrawRewords[to];
                }
            }

            //withdrow deposit
            if(tValue > 0){
                _deposit[to] -= tValue;
                _depositTime[to] = block.timestamp;
            }
        }

        _transferFrom(from, to, value);
    }

    /* 
    * --description function--
    */
    function _deductBonuses(address depositor, uint256 value) private{
        require(_calculateBenefit(_deposit[depositor], _depositTime[depositor], _bonus, _withdrawBonuces[depositor]) >= value, "Not enough funds!");
        _withdrawBonuces[depositor] += value;
    }

    /* 
    * --description function--
    */
    function _deductRewords(address depositor, uint256 value) private{

        uint256 reward = _calculateBenefit(_deposit[depositor], _depositTime[depositor], _reward, _withdrawRewords[depositor]);
        if(_rewardVault >= reward){
            _rewardVault -= reward;
            value -= reward;
            _withdrawRewords[depositor] += value;
        }
    }

    /* 
    * --description function--
    */
    function _calculateBenefit(uint256 deposit, uint256 depositTime, uint256 ratio, uint256 withdraws) private pure returns(uint256){
        uint256 result;
        assembly{
            result := sub(mul(ratio, mul(deposit, depositTime)), withdraws)
        }
        return result;
    }


    // ################## Admin methods ##################
    /*
    * --description function--
    */
    function setRewardCoefficient(uint256 value) public onlyOwner returns(bool){
        _reward = value;
        return true;
    }

    /*
    * --description function--
    */
    function setBonusCoefficient(uint256 value) public onlyOwner returns(bool){
        _bonus = value;
        return true;
    }

    /*
    * --description function--
    */
    function workflow(bool onPause) public onlyOwner returns(bool){
        _paused = onPause;
        return true;
    }

    /*
    * --description function--
    */
    function depositVault(uint256 value) public onlyOwner returns(bool){
        _transferFrom(_msgSender(), address(this), value);
        _rewardVault += value;
        return true;
    }

    /*
    * --description function--
    */
    function withdrawVault(uint256 value) public onlyOwner returns(bool){
        _transferFrom(address(this), _msgSender(), value);
        _rewardVault -= value;
        return true;
    }

}