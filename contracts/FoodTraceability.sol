// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FoodTraceability {
    
    // enunrepresenting the stages of a food batch
    enum State { Harvested, InTransit, Delivered, Spoiled }

    struct FoodBatch {
        uint256 batchId;
        string productName;
        string originFarm;
        address currentOwner;     // Sender or Receiver
        address sender;           // Farmer / Producer
        address receiver;         // Distributor / Retailer
        int256 recordedTemp;      // Temperature in Celsius
        uint256 timestamp;
        State status;
    }

    mapping(uint256 => FoodBatch) public batches;
    uint256 public batchCounter;
    int256 public constant MAX_SAFE_TEMP = 8; // Cold-chain limit: 8°C


    // Events
    event BatchCreated(uint256 indexed batchId, string productName, address indexed sender);
    event ShipmentTransferred(uint256 indexed batchId, address indexed from, address indexed to, int256 temp);
    event DeliveryConfirmed(uint256 indexed batchId, address indexed receiver, State finalStatus);

    //  SENDER (Farmer) registers a new harvest batch onto the Blockchain middle layer
    function createBatch(
        string memory _productName,
        string memory _originFarm,
        address _receiver
    ) public {
        require(_receiver != address(0), "Invalid receiver address");
        require(_receiver != msg.sender, "Sender and receiver must be different");

        batchCounter++;
        batches[batchCounter] = FoodBatch({
            batchId: batchCounter,
            productName: _productName,
            originFarm: _originFarm,
            currentOwner: msg.sender,
            sender: msg.sender,
            receiver: _receiver,
            recordedTemp: 4, // Initial cold storage temp (4°C)
            timestamp: block.timestamp,
            status: State.Harvested
        });

        emit BatchCreated(batchCounter, _productName, msg.sender);

    }
    
    //  MIDDLE LAYER VALIDATION: Sender dispatches batch with IoT temperature reading
    function dispatchBatch(uint256 _batchId, int256 _transitTemp) public {
        FoodBatch storage batch = batches[_batchId];
        require(msg.sender == batch.sender, "Only designated sender can dispatch");
        require(batch.status == State.Harvested, "Batch not ready for dispatch");

        batch.recordedTemp = _transitTemp;
        batch.timestamp = block.timestamp;

        // Smart contract automatically flags spoilage if temperature exceeds limit
        if (_transitTemp > MAX_SAFE_TEMP) {
            batch.status = State.Spoiled;
        } else {
            batch.status = State.InTransit;
        }

        emit ShipmentTransferred(_batchId, batch.sender, batch.receiver, _transitTemp);
    }

    // RECEIVER (Retailer/Distributor) verifies quality and accepts ownership
    function confirmDelivery(uint256 _batchId, int256 _arrivalTemp) public {
        FoodBatch storage batch = batches[_batchId];
        require(msg.sender == batch.receiver, "Only designated receiver can confirm");
        require(batch.status == State.InTransit, "Already spoiled or not in transit");

        batch.recordedTemp = _arrivalTemp; 
        batch.timestamp = block.timestamp;
 
        if (_arrivalTemp > MAX_SAFE_TEMP) { 
            batch.status = State.Spoiled; 
        } else { 
            batch.status = State.Delivered;
            batch.currentOwner = msg.sender; //  Ownershipd transfer
        } 

        emit DeliveryConfirmed(_batchId, msg.sender, batch.status);
    }

    // CONSUMER / AUDITOR query function
    function getBatchDetails(uint256 _batchId) public view returns (
        string memory productName,
        string memory originFarm,
        address sender,
        address receiver,
        address currentOwner,
        int256 recordedTemp,
        State status
    ) {
        FoodBatch memory b = batches[_batchId];
        return (
            b.productName,
            b.originFarm,
            b.sender,
            b.receiver,
            b.currentOwner,
            b.recordedTemp,
            b.status
        );
    }
}