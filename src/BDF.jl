module BDF

using Compat

export readBDF, readBDFHeader, writeBDF, splitBDFAtTime, splitBDFAtTrigger

function readBDF(fname::String; from::Real=0, to::Real=-1)
    #fname: file path
    #from: start time in seconds, default is 0
    #to: end time, default is the full duration
    #returns data, trigChan, sysCodeChan, evtTab

    readBDF(open(fname, "r"), from=from, to=to)
end


function readBDF(fid::IO; from::Real=0, to::Real=-1)

    if isa(fid, IOBuffer)
        fid.ptr = 1
    end

    idCodeNonASCII = read(fid, Uint8, 1)
    idCode = ascii(read(fid, Uint8, 7))
    subjID = ascii(read(fid, Uint8, 80))
    recID = ascii(read(fid, Uint8, 80))
    startDate = ascii(read(fid, Uint8, 8))
    startTime = ascii(read(fid, Uint8, 8))
    nBytes = int(ascii(read(fid, Uint8, 8)))
    versionDataFormat = ascii(read(fid, Uint8, 44))
    nDataRecords = int(ascii(read(fid, Uint8, 8)))
    recordDuration = float(ascii(read(fid, Uint8, 8)))
    nChannels = int(ascii(read(fid, Uint8, 4)))
    chanLabels = Array(String, nChannels)
    transducer = Array(String, nChannels)
    physDim = Array(String, nChannels)
    physMin = Array(Int32, nChannels)
    physMax = Array(Int32, nChannels)
    digMin = Array(Int32, nChannels)
    digMax = Array(Int32, nChannels)
    prefilt = Array(String, nChannels)
    nSampRec = Array(Int, nChannels)
    reserved = Array(String, nChannels)
    scaleFactor = Array(Float32, nChannels)
    sampRate = Array(Int, nChannels)

    duration = recordDuration*nDataRecords

    for i=1:nChannels
        chanLabels[i] = strip(ascii(read(fid, Uint8, 16)))
    end

    for i=1:nChannels
        transducer[i] = strip(ascii(read(fid, Uint8, 80)))
    end

    for i=1:nChannels
        physDim[i] = strip(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        physMin[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        physMax[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        digMin[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        digMax[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        prefilt[i] = strip(ascii(read(fid, Uint8, 80)))
    end

    for i=1:nChannels
        nSampRec[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        reserved[i] = strip(ascii(read(fid, Uint8, 32)))
    end

    for i=1:nChannels
        scaleFactor[i] = float32(physMax[i]-physMin[i])/(digMax[i]-digMin[i])
        sampRate[i] = nSampRec[i]/recordDuration
    end
  
    if to < 1
        to = nDataRecords
    end
    recordsToRead = to - from
    data = Array(Int32, ((nChannels-1), (recordsToRead*nSampRec[1])))
    trigChan = Array(Int16, recordsToRead*nSampRec[1])
    sysCodeChan = Array(Int16,  recordsToRead*nSampRec[1])

    startPos = 3*from*nChannels*nSampRec[1]
    skip(fid, startPos)
    x = read(fid, Uint8, 3*recordsToRead*nChannels*nSampRec[1])
    pos = 1
    for n=1:recordsToRead
        for c=1:nChannels
            if chanLabels[c] != "Status"
                for s=1:nSampRec[1]
                    data[c,(n-1)*nSampRec[1]+s] = ((int32(x[pos]) << 8) | (int32(x[pos+1]) << 16) | (int32(x[pos+2]) << 24) )>> 8
                    pos = pos+3
                end
            else
                for s=1:nSampRec[1]
                    trigChan[(n-1)*nSampRec[1]+s] = ((uint16(x[pos])) | (uint16(x[pos+1]) << 8)) & 255
                    sysCodeChan[(n-1)*nSampRec[1]+s] = int16(x[pos+2])
                    pos = pos+3
                end
            end
        end
    end
    data = data*scaleFactor[1]
    close(fid)


    startPoints = vcat(1, find(diff(trigChan) .!= 0).+1)
    stopPoints = vcat(find(diff(trigChan) .!= 0), length(trigChan))
    trigDurs = (stopPoints - startPoints)/sampRate[1]

    evt = trigChan[startPoints]
    @compat evtTab = Dict{String,Any}("code" => evt,
                                      "idx" => startPoints,
                                      "dur" => trigDurs
                                      )

    return data, evtTab, trigChan, sysCodeChan

end



function readBDFHeader(fileName::String)
    fid = open(fileName, "r")
    idCodeNonASCII = read(fid, Uint8, 1)
    idCode = ascii(read(fid, Uint8, 7))
    subjID = ascii(read(fid, Uint8, 80))
    recID = ascii(read(fid, Uint8, 80))
    startDate = ascii(read(fid, Uint8, 8))
    startTime = ascii(read(fid, Uint8, 8))
    nBytes = int(ascii(read(fid, Uint8, 8)))
    versionDataFormat = ascii(read(fid, Uint8, 44))
    nDataRecords = int(ascii(read(fid, Uint8, 8)))
    recordDuration = float(ascii(read(fid, Uint8, 8)))
    nChannels = int(ascii(read(fid, Uint8, 4)))
    chanLabels = Array(String, nChannels)
    transducer = Array(String, nChannels)
    physDim = Array(String, nChannels)
    physMin = Array(Int32, nChannels)
    physMax = Array(Int32, nChannels)
    digMin = Array(Int32, nChannels)
    digMax = Array(Int32, nChannels)
    prefilt = Array(String, nChannels)
    nSampRec = Array(Int, nChannels)
    reserved = Array(String, nChannels)
    scaleFactor = Array(Float32, nChannels)
    sampRate = Array(Int, nChannels)

    duration = recordDuration*nDataRecords

    for i=1:nChannels
        chanLabels[i] = strip(ascii(read(fid, Uint8, 16)))
    end

    for i=1:nChannels
        transducer[i] = strip(ascii(read(fid, Uint8, 80)))
    end

    for i=1:nChannels
        physDim[i] = strip(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        physMin[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        physMax[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        digMin[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        digMax[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        prefilt[i] = strip(ascii(read(fid, Uint8, 80)))
    end

    for i=1:nChannels
        nSampRec[i] = int(ascii(read(fid, Uint8, 8)))
    end

    for i=1:nChannels
        reserved[i] = strip(ascii(read(fid, Uint8, 32)))
    end

    for i=1:nChannels
        scaleFactor[i] = float32(physMax[i]-physMin[i])/(digMax[i]-digMin[i])
        sampRate[i] = nSampRec[i]/recordDuration
    end

    close(fid)

@compat d = Dict{String,Any}("fileName" => fileName,
                             "idCodeNonASCII" => idCodeNonASCII,
                             "idCode" => idCode,
                             "subjID" => subjID,
                             "recID"  => recID,
                             "startDate" => startDate,
                             "startTime" => startTime,
                             "nBytes" => nBytes,
                             "versionDataFormat" => versionDataFormat,
                             "nDataRecords"  => nDataRecords,
                             "recordDuration" => recordDuration,
                             "nChannels"  => nChannels,
                             "chanLabels"  => chanLabels,
                             "transducer"  => transducer,
                             "physDim"=> physDim,
                             "physMin" => physMin,
                             "physMax" => physMax,
                             "digMin" => digMin,
                             "digMax" => digMax,
                             "prefilt" => prefilt,
                             "nSampRec" => nSampRec,
                             "reserved" => reserved,
                             "scaleFactor" => scaleFactor,
                             "sampRate" => sampRate,
                             "duration" => duration,
                             )
    return(d)
    
end

function writeBDF(fname::String, data, trigChan, statusChan, sampRate; subjID="",
                  recID="", startDate=strftime("%d.%m.%y", time()),  startTime=strftime("%H.%M.%S", time()), versionDataFormat="24BIT",
                  chanLabels=["" for i=1:size(data)[1]], transducer=["" for i=1:size(data)[1]],
                  physDim=["" for i=1:size(data)[1]],
                  physMin=[-262144 for i=1:size(data)[1]], physMax=[262144 for i=1:size(data)[1]],
                  prefilt=["" for i=1:size(data)[1]])

    #check data values within physMin physMax range
    for i=1:size(data)[1]
        if (maximum(data[i,:]) > physMax[i]) | (minimum(data[i,:]) < physMin[i])
            error("Data values exceed [physMin, physMax] range, exiting!")
        end
    end
    # and check also trigs and status don't go over allowed range
    if (maximum(trigChan) > 2^16-1) | (minimum(trigChan) < 0)
        error("trigger values exceed allowed range [0, 65535] range, exiting!")
    end
    if (maximum(statusChan) > 2^8-1) | (minimum(statusChan) < 0)
        error("status channel values exceed allowed range [0, 255] range, exiting!")
    end
    
    modulo = mod(size(data)[2], sampRate)
    if modulo == 0
        padSize = 0
    else
        padSize = int(sampRate - modulo)
    end
    dats = hcat(data, zeros(eltype(data), size(data)[1], padSize))
    trigs = vcat(trigChan, zeros(eltype(trigChan), padSize))
    statChan = vcat(statusChan, zeros(eltype(statusChan), padSize))
    ## dats = copy(data) #data are modified (scaled, converted to int) need to copy to avoid mofifying original data
    ## trigs = copy(trigChan)
    ## statChan = copy(statusChan)
    nChannels = size(dats)[1] + 1
    nSamples = size(dats)[2]
    fid = open(fname, "w")
    
    write(fid, 0xff)
    idCode = "BIOSEMI"
    for i=1:length(idCode)
        write(fid, uint8(idCode[i]))
    end
    #subjID
    nSubjID = length(subjID)
    if nSubjID > 80
        println("subjID longer than 80 characters, truncating!")
        subjID = subjID[1:80]
        nSubjID = length(subjID)
    end
    for i=1:nSubjID
        write(fid, uint8(subjID[i]))
    end
    for i=1:(80-nSubjID)
        write(fid, char(' '))
    end
    #recID
    nRecID = length(recID)
    if nRecID > 80
        println("recID longer than 80 characters, truncating!")
        recID = recID[1:80]
        nRecID = length(recID)
    end
    for i=1:nRecID
        write(fid, uint8(recID[i]))
    end
    for i=1:(80-nRecID)
        write(fid, char(' '))
    end
    #startDate
    nStartDate = length(startDate)
    if nStartDate > 8
        println("startDate longer than 8 characters, truncating!")
        startDate = startDate[1:8]
        nStartDate = length(startDate)
    end
    for i=1:nStartDate
        write(fid, uint8(startDate[i]))
    end
    for i=1:(8-nStartDate)
        write(fid, char(' '))
    end
    #startTime
    nStartTime = length(startTime)
    if nStartTime > 8
        println("startTime longer than 8 characters, truncating!")
        startTime = startTime[1:8]
        nStartTime = length(startTime)
    end
    for i=1:nStartTime
        write(fid, uint8(startTime[i]))
    end
    for i=1:(8-nStartTime)
        write(fid, char(' '))
    end
    #nBytes
    nBytes = string((nChannels+1)*256)
    for i=1:length(nBytes)
        write(fid, uint8(nBytes[i]))
    end
    for i=1:(8-length(nBytes))
        write(fid, char(' '))
    end
    #versionDataFormat
    nVersionDataFormat = length(versionDataFormat)
    if nVersionDataFormat > 44
        println("versionDataFormat longer than 44 characters, truncating!")
        versionDataFormat = versionDataFormat[1:44]
        nVersionDataFormat = length(versionDataFormat)
    end
    for i=1:nVersionDataFormat
        write(fid, uint8(versionDataFormat[i]))
    end
    for i=1:(44-nVersionDataFormat)
        write(fid, char(' '))
    end
    #nDataRecords
    nDataRecords = int(ceil(size(dats)[2]/sampRate))
    nDataRecordsString = string(nDataRecords)
    for i=1:length(nDataRecordsString)
        write(fid, uint8(nDataRecordsString[i]))
    end
    for i=1:(8-length(nDataRecordsString))
        write(fid, char(' '))
    end
    #recordDuration
    recordDuration = "1       "
    for i=1:length(recordDuration)
        write(fid, uint8(recordDuration[i]))
    end
    #nChannels
    nChannelsString = string(nChannels)
    for i=1:length(nChannelsString)
        write(fid, uint8(nChannelsString[i]))
    end
    for i=1:(4-length(nChannelsString))
        write(fid, char(' '))
    end
    #chanLabels
    if length(chanLabels) > nChannels -1
        println("Number of chanLabels greater than number of channels, truncating!")
        chanLabels = chanLabels[1:nChannels-1]
    end
    if length(chanLabels) < nChannels -1
        #println("Warning: number of chanLabels less than number of channels!")
        chanLabels = vcat(chanLabels, ["" for k=1:(nChannels-1)-length(chanLabels)])
        
    end
    for j=1:length(chanLabels)
        for i=1:length(chanLabels[j])
            write(fid, uint8(chanLabels[j][i]))
        end
        for i=1:(16-length(chanLabels[j]))
            write(fid, char(' '))
        end
    end
    statusString = "Status"
    for i=1:length(statusString)
        write(fid, uint8(statusString[i]))
    end
    for i=1:(16-length(statusString))
        write(fid, char(' '))
    end

    #transducer
    if length(transducer) > nChannels -1
        println("Number of transducer greater than number of channels, truncating!")
        transducer = transducer[1:nChannels-1]
    end
    if length(transducer) < nChannels-1
        #println("Warning: number of transducer less than number of channels!")
        transducer = vcat(transducer, ["" for k=1:(nChannels-1)-length(transducer)])
    end
    for j=1:length(transducer)
        for i=1:length(transducer[j])
            write(fid, uint8(transducer[j][i]))
        end
        for i=1:(80-length(transducer[j]))
            write(fid, char(' '))
        end
    end
    trigStatusString = "Triggers and Status"
    for i=1:length(trigStatusString)
        write(fid, uint8(trigStatusString[i]))
    end
    for i=1:(80-length(trigStatusString))
        write(fid, char(' '))
    end

    #physDim
    if length(physDim) > nChannels-1
        println("Number of physDim greater than number of channels, truncating!")
        physDim = physDim[1:nChannels-1]
    end
    if length(physDim) < nChannels-1
        #println("Warning: number of physDim less than number of channels!")
        physDim = vcat(physDim, ["" for k=1:(nChannels-1)-length(physDim)])
    end
    for j=1:length(physDim)
        for i=1:length(physDim[j])
            write(fid, uint8(physDim[j][i]))
        end
        for i=1:(8-length(physDim[j]))
            write(fid, char(' '))
        end
    end
    boolString = "Boolean"
    for i=1:length(boolString)
        write(fid, uint8(boolString[i]))
    end
    for i=1:(8-length(boolString))
        write(fid, char(' '))
    end
    if length(physMin) !=  nChannels-1
        error("Length of physMin must match number of data channels, exiting!")
    end
    if length(physMax) !=  nChannels-1
        error("Length of physMax must match number of data channels, exiting!")
    end
    physMin = vcat(physMin, -8388608)
    physMax = vcat(physMax, 8388607)
    digMin = [-8388608 for i=1:nChannels]
    digMax = [8388607 for i=1:nChannels]
    physMinString = [string(physMin[i]) for i=1:length(physMin)]
    physMaxString = [string(physMax[i]) for i=1:length(physMax)]
    digMinString = [string(digMin[i]) for i=1:length(digMin)]
    digMaxString = [string(digMax[i]) for i=1:length(digMax)]
    for j=1:length(physMinString)
        for i=1:length(physMinString[j])
            write(fid, uint8(physMinString[j][i]))
        end
        for i=1:(8-length(physMinString[j]))
            write(fid, char(' '))
        end
    end
    for j=1:length(physMaxString)
        for i=1:length(physMaxString[j])
            write(fid, uint8(physMaxString[j][i]))
        end
        for i=1:(8-length(physMaxString[j]))
            write(fid, char(' '))
        end
    end
    for j=1:length(digMinString)
        for i=1:length(digMinString[j])
            write(fid, uint8(digMinString[j][i]))
        end
        for i=1:(8-length(digMinString[j]))
            write(fid, char(' '))
        end
    end
    for j=1:length(digMaxString)
        for i=1:length(digMaxString[j])
            write(fid, uint8(digMaxString[j][i]))
        end
        for i=1:(8-length(digMaxString[j]))
            write(fid, char(' '))
        end
    end

    #prefilt
    if length(prefilt) > nChannels-1
        println("Number of prefilt greater than number of channels, truncating!")
        prefilt = prefilt[1:nChannels-1]
    end
    if length(prefilt) < nChannels-1
        #println("Warning: number of prefilt less than number of channels!")
        prefilt = vcat(prefilt, ["" for k=1:(nChannels-1)-length(prefilt)])
    end
    for j=1:length(prefilt)
        for i=1:length(prefilt[j])
            write(fid, uint8(prefilt[j][i]))
        end
        for i=1:(80-length(prefilt[j]))
            write(fid, char(' '))
        end
    end
    noFiltString = "No filtering"
    for i=1:length(noFiltString)
        write(fid, uint8(noFiltString[i]))
    end
    for i=1:(80-length(noFiltString))
        write(fid, char(' '))
    end

    #nSampRec
    nSampRec = sampRate
    nSampRecString = string(sampRate)
    for j=1:nChannels
        for i=1:length(nSampRecString)
            write(fid, uint8(nSampRecString[i]))
        end
        for i=1:(8-length(nSampRecString))
            write(fid, char(' '))
        end
    end

    #reserved
    for j=1:nChannels
        reservedString = "Reserved"
        for i=1:length(reservedString)
            write(fid, uint8(reservedString[i]))
        end
        for i=1:(32-length(reservedString))
            write(fid, char(' '))
        end
    end

    scaleFactor = zeros(nChannels)
    for i=1:nChannels
        scaleFactor[i] = float32(physMax[i]-physMin[i])/(digMax[i]-digMin[i])
    end
    for i=1:nChannels-1
        dats[i,:] = dats[i,:] /scaleFactor[i]
    end
   
    dats = int32(dats) #need to pad dats
    trigs = int16(trigs)
    statChan = int16(statChan)
    for n=1:nDataRecords
        for c=1:nChannels
            if c < nChannels
                for s=1:nSampRec
                    thisSample = dats[c,(n-1)*nSampRec+s]
                    write(fid, uint8(thisSample));   write(fid, uint8(thisSample >> 8)); write(fid, uint8(thisSample >> 16));
                end
            else
                for s=1:nSampRec
                    thisTrig = trigs[(n-1)*nSampRec[1]+s]
                    thisStatus = statChan[(n-1)*nSampRec[1]+s]
                    write(fid, uint8(thisTrig)); write(fid, uint8(thisTrig >> 8)); write(fid, uint8(thisStatus));
                end
            end
        end
    end
  
    close(fid)
end

function splitBDFAtTrigger(fname::String, trigger::Int; from::Real=0, to::Real=-1)

    data, evtTab, trigChan, sysCodeChan = readBDF(fname, from=from, to=to)
    origHeader = readBDFHeader(fname)
    sampRate = origHeader["sampRate"][1] #assuming sampling rate is the same for all channels
    sepPoints = evtTab["idx"][find(evtTab["code"] .== trigger)]
    nChunks = length(sepPoints)+1
    startPoints = [1,         sepPoints.+1]
    stopPoints =  [sepPoints, size(data)[2]] 
    
    for i=1:nChunks
        thisFname = string(split(fname, ".")[1], "_", i, ".", split(fname, ".")[2])
        thisData = data[:, startPoints[i]: stopPoints[i]]
        thisTrigChan = trigChan[startPoints[i]: stopPoints[i]]
        thisSysCodeChan = sysCodeChan[startPoints[i]: stopPoints[i]]

        writeBDF(thisFname, thisData, thisTrigChan, thisSysCodeChan, sampRate; subjID=origHeader["subjID"],
             recID=origHeader["recID"], startDate=strftime("%d.%m.%y", time()),  startTime=strftime("%H.%M.%S", time()), versionDataFormat="24BIT",
             chanLabels=origHeader["chanLabels"][1:end-1], transducer=origHeader["transducer"][1:end-1],
             physDim=origHeader["physDim"][1:end-1],
             physMin=origHeader["physMin"][1:end-1], physMax=origHeader["physMax"][1:end-1],
             prefilt=origHeader["prefilt"][1:end-1])
    end
end

function splitBDFAtTime(fname::String, timeSeconds; from::Real=0, to::Real=-1)

    data, evtTab, trigChan, sysCodeChan = readBDF(fname, from=from, to=to)
    origHeader = readBDFHeader(fname)
    sampRate = origHeader["sampRate"][1] #assuming sampling rate is the same for all channels
    sepPoints = int(round(sampRate.*timeSeconds))
    for i=1:length(sepPoints)
        if sepPoints[i] > size(data)[2]
            error("Split point exceeds data points")
        end
    end
    nChunks = length(timeSeconds)+1
    startPoints = [1,         sepPoints.+1]
    stopPoints =  [sepPoints, size(data)[2]]

    for i=1:nChunks
        thisFname = string(split(fname, ".")[1], "_", i, ".", split(fname, ".")[2])
        thisData = data[:, startPoints[i]: stopPoints[i]]
        thisTrigChan = trigChan[startPoints[i]: stopPoints[i]]
        thisSysCodeChan = sysCodeChan[startPoints[i]: stopPoints[i]]

        writeBDF(thisFname, thisData, thisTrigChan, thisSysCodeChan, sampRate; subjID=origHeader["subjID"],
             recID=origHeader["recID"], startDate=strftime("%d.%m.%y", time()),  startTime=strftime("%H.%M.%S", time()), versionDataFormat="24BIT",
             chanLabels=origHeader["chanLabels"][1:end-1], transducer=origHeader["transducer"][1:end-1],
             physDim=origHeader["physDim"][1:end-1],
             physMin=origHeader["physMin"][1:end-1], physMax=origHeader["physMax"][1:end-1],
             prefilt=origHeader["prefilt"][1:end-1])
    end
end

end # module
