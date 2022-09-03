// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../shared/Reentry/ReentryProtection.sol";

import "./Club250Base.sol";
import "./LibClub250Storage.sol";
import "../shared/Access/CallProtection.sol";
import "../ERC20/LibERC20.sol";
import "hardhat/console.sol";

contract PremiumBase is Club250Base, CallProtection, ReentryProtection {
    using SafeMath for uint256;

    event NewUpgrade(address indexed by, uint256 indexed id);

    event PremiumReferralPayout(uint256 indexed userID, uint256 indexed referralID, uint256 amount);

    event MatrixPayout(uint256 indexed userID, uint256 indexed fromID, uint256 amount);

    event NewLevel(uint256 indexed userID, uint256 indexed level);

    function hasEmptyLegs(uint256 userID, uint256 part) private view returns (bool) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        return es.matrices[userID][part].left == 0 || es.matrices[userID][part].right == 0;
    }

    // @dev returns the upline of the user in the supplied part.
    // part must be 2 and above.
    // part 1 should use the get getPremiumSponsor
    function getUplineInPart(
        uint256 userID,
        uint256 part,
        int256 callDept
    ) internal view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(part > 1, "IPFU");
        if (es.matrices[userID][part].registered) {
            return es.matrices[userID][part].uplineID;
        }

        uint256 p1up = es.matrices[userID][1].uplineID;
        if (es.matrices[p1up][part].registered) {
            return p1up;
        }

        if (callDept >= 50) {
            return 1;
        }

        return getUplineInPart(p1up, part, callDept + 1);
    }

    // @dev return user ID that has space in the matrix of the supplied upline ID
    // @dev uplineID must be a premium account in the supplied part
    function getAvailableUplineInMatrix(
        uint256 uplineID,
        uint256 part,
        bool traverseDown,
        uint256 random
    ) internal view returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        require(uplineID > 0, "ZU");
        require(es.matrices[uplineID][part].registered, "UNIP");

        if (hasEmptyLegs(uplineID, part)) {
            return uplineID;
        }

        uint256 arraySize = 2 * ((2**es.traversalDept) - 1);
        uint256 previousLineSize = 2 * ((2**(es.traversalDept - 1)) - 1);
        uint256[] memory referrals = new uint256[](arraySize);
        referrals[0] = es.matrices[uplineID][part].left;
        referrals[1] = es.matrices[uplineID][part].right;

        uint256 referrer;

        for (uint256 i = 0; i < arraySize; i++) {
            if (hasEmptyLegs(referrals[i], part)) {
                referrer = referrals[i];
                break;
            }

            if (i < previousLineSize) {
                referrals[(i + 1) * 2] = es.matrices[referrals[i]][part].left;
                referrals[(i + 1) * 2 + 1] = es.matrices[referrals[i]][part].right;
            }
        }

        if (referrer == 0 && traverseDown) {
            if (random < previousLineSize) {
                random = random.add(previousLineSize);
            }
            if (random > arraySize) {
                random = arraySize % random;
            }
            referrer = getAvailableUplineInMatrix(referrals[random], part, false, random);

            if (referrer == 0) {
                for (uint256 i = previousLineSize; i < arraySize; i++) {
                    referrer = getAvailableUplineInMatrix(referrals[random], part, false, random);
                    if (referrer != 0) {
                        break;
                    }
                }
                require(referrer > 0, "RNF");
            }
        }

        return referrer;
    }

    function blockDownlines(
        uint256[16] memory ids,
        uint256 level,
        uint256 gen
    ) internal view returns (uint256[16] memory) {
        if (gen == 0) {
            return ids;
        }

        uint256[16] memory result;
        uint256 resultCount;
        for (uint256 i = 0; i < 16; i++) {
            if (ids[i] == 0) {
                break;
            }
            (uint256 left, , uint256 right, ) = getDirectLegs(ids[i], level);
            if (left > 0) {
                result[resultCount] = left;
                resultCount += 1;
            }

            if (right > 0) {
                result[resultCount] = right;
                resultCount += 1;
            }
        }

        return blockDownlines(result, level, gen - 1);
    }

    function getDirectLegs(uint256 userID, uint256 level)
        public
        view
        returns (
            uint256 left,
            uint256 leftLevel,
            uint256 right,
            uint256 rightLevel
        )
    {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 part = getPartFromLevel(level);
        require(es.matrices[userID][part].registered, "IVL");

        left = es.matrices[userID][part].left;
        leftLevel = es.users[left].premiumLevel;

        right = es.matrices[userID][part].right;
        rightLevel = es.users[right].premiumLevel;
    }

    function sendMatrixPayout(uint256 fromID, uint256 level) internal returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 part = getPartFromLevel(level);
        uint256 beneficiary = getUplineAtBlock(fromID, part, es.levelConfigurations[level].paymentGeneration);
        // @dev this may happen as the imported data is not trusted to be in the right format
        if (_getMatrixPayoutCount(beneficiary, level) >= es.levelConfigurations[level].numberOfPayments && beneficiary != 1) {
            return beneficiary;
        }

        if (es.users[beneficiary].premiumLevel < level) {
            return beneficiary;
        }

        sendPayout(es.userAddresses[beneficiary], amountFromDollar(es.levelConfigurations[level].perDropEarning));
        emit MatrixPayout(beneficiary, fromID, es.levelConfigurations[level].perDropEarning);

        return beneficiary;
    }

    function _getMatrixPayoutCount(uint256 userID, uint256 level) internal view returns (uint256) {
        uint256[16] memory input;
        input[0] = userID;
        uint256[16] memory ids = blockDownlines(input, level, LibClub250Storage.club250Storage().levelConfigurations[level].paymentGeneration);
        uint256 count;
        for (uint256 i = 0; i < 16; i++) {
            if (ids[i] == 0) {
                continue;
            }
            if (LibClub250Storage.club250Storage().users[ids[i]].premiumLevel >= level) {
                count += 1;
            }
        }
        return count;
    }

    function getUplineAtBlock(
        uint256 userID,
        uint256 part,
        uint256 depth
    ) internal returns (uint256) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        if (userID == 1) return 1;
        if (depth == 1) {
            return es.matrices[userID][part].uplineID;
        }

        return getUplineAtBlock(es.matrices[userID][part].uplineID, part, depth - 1);
    }

    function moveToNextLevel(uint256 userID, uint256 random) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        if (userID == 1) return;

        uint256 newLevel = es.users[userID].premiumLevel + 1;
        // @dev add to matrix if change in level triggers change in part
        if (getPartFromLevel(newLevel) > getPartFromLevel(es.users[userID].premiumLevel)) {
            addToMatrix(userID, newLevel, random);
        }
        es.users[userID].premiumLevel = newLevel;

        emit NewLevel(userID, newLevel);
        // #dev send pending payments in this level
        uint256 pendingPayoutCount = _getMatrixPayoutCount(userID, newLevel);
        if (pendingPayoutCount > 0) {
            uint256 pendingAmount = pendingPayoutCount.mul(es.levelConfigurations[newLevel].perDropEarning);
            sendPayout(es.userAddresses[userID], amountFromDollar(pendingAmount));
        }

        uint256 benefactor = sendMatrixPayout(userID, newLevel);

        if (levelCompleted(benefactor) && benefactor != 1) {
            moveToNextLevel(benefactor, random);
        }
    }

    function addToMatrix(
        uint256 userID,
        uint256 level,
        uint256 random
    ) internal {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        uint256 part = getPartFromLevel(level);
        uint256 uplineID = getUplineInPart(userID, part, 0);
        uint256 matrixUpline = getAvailableUplineInMatrix(uplineID, part, true, random);
        es.matrices[userID][part].registered = true;
        es.matrices[userID][part].uplineID = matrixUpline;
        if (es.matrices[matrixUpline][part].left == 0) {
            es.matrices[matrixUpline][part].left = userID;
        } else {
            es.matrices[matrixUpline][part].right = userID;
        }
    }

    function levelCompleted(uint256 userID) internal view returns (bool) {
        LibClub250Storage.CLUB250Storage storage es = LibClub250Storage.club250Storage();
        if (userID == 1) {
            return true;
        }
        uint256 lineCount = _getMatrixPayoutCount(userID, es.users[userID].premiumLevel);

        return lineCount == es.levelConfigurations[es.users[userID].premiumLevel].numberOfPayments;
    }

    function getPartFromLevel(uint256 level) internal pure returns (uint256) {
        require(level > 0 && level <= 18, "IPL");
        if (level < 3) {
            return 1;
        }
        if (level < 6) {
            return 2;
        }
        if (level < 9) {
            return 3;
        }
        if (level < 12) {
            return 4;
        }
        if (level < 15) {
            return 5;
        }
        return 6;
    }

    function levelFromPart(uint256 part) internal pure returns (uint256) {
        if (part == 1) {
            return 1;
        }
        if (part == 2) {
            return 3;
        }
        if (part == 3) {
            return 6;
        }
        if (part == 4) {
            return 9;
        }
        if (part == 12) {
            return 1;
        }
        if (part == 6) {
            return 15;
        }

        return 0;
    }
}
