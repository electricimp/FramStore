class FramStore {
    // Defines a FRAM store – ie. the combined storage of 1-8 FRAM chips

    static VERSION = [1,0,0];

    _store = null;
    _chipCount = 0;
    _minAddress = 0;
    _maxAddress = 0;
    _debug = false;

    constructor (frams = null, debug = false) {
        // Note, frams == null is a valid configuration
        if (frams != null) {
            // Convert a single fram object to an array of len() 1
            if (typeof frams != "array") frams = [frams];

            // Make sure no more than 8 FRAM chips are included
            if (frams.len() > 8) {
                server.error("Misconstructed FRAM store: only 1-8 FRAM chip objects");
                return null;
            }

            // Set the chip count to the array size
            _chipCount = frams.len();
        } else {
            // No FRAM chip objects passed in so set the chip count to zero
            _chipCount = 0;
        }

        _debug = debug;
        _store = array(_chipCount);

        if (_chipCount > 0) {
            foreach (i, chip in frams) {
                // Add each chip to the _store array. Chip must be configured first
                _store[i] = _newFram(chip);
                if (_debug) server.log("Adding FRAM " + i + " at address " + format("0x%04X", _store[i].startAddress));
            }
        }
    }

    function addFrams(frams = null) {
        // User adds a pre-configured FRAM object to the store
        // Returns 'true' on success, 'false' on failure
        if (frams == null) {
            server.error("You must pass a non-null FRAM chip object to addFrams");
            return false;
        }

        if (_chipCount == 8) {
            // Maximum FRAMs added already
            server.error("Cannot add more FRAM chips to store");
            return false;
        }

        // Convert single fram object to an array of len() 1
        if (typeof frams != "array") frams = [frams];

        if (frams.len() > 8 - _chipCount) {
            // Adding all the passed FRAMs will exceed the maximum chip coint (8)
            server.error("Can only add " + (8 - _chipCount) + " more FRAM chips to store");
            return false;
        }

        foreach (i, chip in frams) {
            _store.append(_newFram(chip));
            ++_chipCount;
            if (_debug) server.log("Adding FRAM " + _chipCount + " at address " + format("0x%04X", _store[i].startAddress));
        }

        return true;
    }

    function clear(value = 0) {
        // Run through each chip in the store and zero it
        foreach (chip in _store) {
            chip.fram.clear(value);
        }
    }

    function readByte(addr = 0) {
        // Calculates the specific FRAM address from the store address
        // and returns the required byte as a single-character string
        if (addr >= _maxAddress || addr < 0) return -1;
        local block = _getBlock(addr);
        local chip = framFromIndex(block);
        local subAddr = addr - (block * (chip.csize() / 8) * 1024);
        return chip.readByte(subAddr);
    }

    function writeByte(addr = 0, byte = 0) {
        // Calculates the specific FRAM address from the store address
        // and writes the specified byte there
        if (addr >= _maxAddress || addr < 0) return -1;
        if (byte < 0 || byte > 0xFF) return -1;
        local block = _getBlock(addr);
        local chip = framFromIndex(block);
        local subAddr = addr - (block * (chip.csize() / 8) * 1024);
        return chip.writeByte(subAddr, byte);
    }

    function readBlob(startAddr = 0, numBytes = 1) {
        // Reads bytes from the store and writes them into a blob
        // which is then returned. Only goes to end of store
        if (startAddr >= _maxAddress || startAddr < 0) return -1;
        if (numBytes < 1) return -1;

        local b = blob(numBytes);
        for (local i = 0 ; i < numBytes ; ++i) {
            local v = readByte(startAddr + i);
            if (v == -1) break;
            b.writen(v, 'b');
        }

        return b;
    }

    function writeBlob(startAddr = 0, data = null, wrap = false) {
        // Writes the contents of a passed blob into the store at the
        // specified address. Only wraps data that exceeds the end of
        // the store if requested (lost otherwise)
        if (startAddr >= _maxAddress || startAddr < 0) return -1;
        if (data == null) return -1;

        data.seek(0, 'b');
        local end = startAddr + data.len();
        if (end < _maxAddress) {
            for (local i = startAddr ; i < end ; ++i) {
                writeByte(i, data.readn('b'));
            }
        } else {
            // Write up to the end of the store
            for (local i = startAddr ; i < _maxAddress ; ++i) {
                writeByte(i, data.readn('b'));
            }

            if (wrap) {
                // If wrap is true, write the remaining bytes
                // at the start of the store
                local v = data.len() - data.tell();
                for (local i = 0 ; i < v ; ++i) {
                    writeByte(i, data.readn('b'));
                }
            }
        }
    }

    function readString(startAddr = 0, numChars = 1) {
        // Reads bytes from the store and writes them into a string
        // which is then returned. Only goes to end of store
        if (startAddr >= _maxAddress || startAddr < 0) return -1;
        if (numChars < 1) return -1;

        local s = "";
        for (local i = 0 ; i < numChars ; ++i) {
            local v = readByte(startAddr + i);
            if (v == -1) break;
            s = s + v;
        }

        return s;
    }

    function writeString(startAddr = 0, string = null, wrap = false) {
        // Writes the contents of a passed blob into the store at the
        // specified address. Only wraps data that exceeds the end of
        // the store if requested (lost otherwise)
        if (startAddr >= _maxAddress || startAddr < 0) return -1;
        if (string == null || string.len() == 0) return -1;

        local end = startAddr + string.len();
        if (end < _maxAddress) {
            for (local i = startAddr ; i < end ; ++i) {
                writeByte(i, string[i - startAddr]);
            }
        } else {
            // Write up to the end of the store
            local c = 0;
            for (local i = startAddr ; i < _maxAddress ; ++i) {
                writeByte(i, string[i - startAddr]);
                ++c;
            }

            if (wrap) {
                // If wrap is true, write the remaining bytes
                // at the start of the store
                local v = string.len() - c;
                for (local i = 0 ; i < v ; ++i) {
                    writeByte(i, string[i + c]);
                }
            }
        }
    }

    function chipCount() {
        // Return the number of chips in the store
        return _chipCount;
    }

    function maxAddress() {
        // Return the top address (+1)
        return _maxAddress;
    }

    function framFromAddress(addr = 0) {
        // Return a reference to the specific FRAM chip that
        // holds the specified address in the store

        if (addr < 0 || addr > _maxAddress) {
            server.error("FRAM address out of range");
            return null;
        }

        local block = addr / 32768;
        local a = _store[block];
        return a.fram;
    }

    function framFromIndex(index = 0) {
        // Return a reference to the specific FRAM chip
        // specified by its index in the _frams array

        if (index < 0 || index == _chipCount) {
            server.error("FRAM index out of range");
            return null;
        }

        local a = _store[index];
        return a.fram;
    }

    // PRIVATE FUNCTIONS

    function _getBlock(addr) {
        // Find the index in the _store array of the fram object which contains addr
        for (local i = 0 ; i < _store.len() ; ++i) {
            local f = _store[i];
            if (addr >= f.startAddress && addr <= f.endAddress) return i;
        }
    }

    function _newFram(aChip) {
        local newFram = {};
        newFram.startAddress <- _maxAddress;
        _maxAddress = _maxAddress + aChip.maxAddress();
        newFram.endAddress <- _maxAddress - 1;
        newFram.fram <- aChip;
        return newFram;
    }
}
