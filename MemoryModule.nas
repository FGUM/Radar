#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Module to add a memory for past echoes to the radar.
# Extends `FGUM.Radar.MOLG.Module` to act as computing module in the modular workflow of filtering contacts.
# 

MemoryModule = {
    #! \brief   MemoryModule constructor.
    #! \details Instantiate a new MOLG.Module to keep the contacts echoes in memory for a certain amount of time.
    #! \param   echoNodeName: The MOLG node name containing raw echo data (string).
    #! \param   memoryNodeName: The MOLG node name to be updated with the memory data (string).
    #! \param   timeToKeepEchos: The time an echo will be kept in memory (seconds).
    new: func (echoNodeName, memoryNodeName, timeToKeepEchos){
        var me = {parents: [MemoryModule, 
                            FGUM_Radar_MOLG.Module.new(std.Vector.new([echoNodeName]),      # Module dependencies: The graph node that defines whether an echo was received from the target or not. 
                                                       std.Vector.new([memoryNodeName]))]};  # Module outputs: The node guaranteed to be satisfied by the memory module (compute function).
        
        me.echoNodeName   = echoNodeName;
        me.memoryNodeName  = memoryNodeName;
        me.timeToKeepEchos = timeToKeepEchos;
        me.frameTime = 0;
        
        return me;
    },
    
    #! \brief     Keep track of the time of the current frame.
    #! \details   Update the members to provide context-based data for the filtering step.
    #! \overrides MOLG.Module.update(graph, dt) (pure virtual := nil).
    #! \param     radar: The Radar => MOLG.Kernel instance this module belongs to (Radar).
    #! \param     dt: The delta time of the radar to simulate (seconds).
    update: func(radar, dt){
        me.frameTime = getprop("sim/time/elapsed-sec");
    },
    
    
    #! \brief     Save a contact echo in memory, and compute whether or not the contact produced an echo in the last "timeToKeepEchos" seconds.
    #! \overrides MOLG.Module.compute(graph, id) (pure virtual := nil).
    #! \param     radar: The Radar => MOLG.Kernel instance this module belongs to (Radar).
    #! \param     dt: The delta time of the radar to simulate (seconds).
    compute: func(radar, id){
        # If there was an echo in the current scan frame.
        if(graph.nodesContent[me.echoNodeName][id])
            # Update the last echo time of the contact.
            radar.rawData[id].echoTime = me.frameTime;
        
        # If the last echo of the contact happened more than me.timeToKeepEchos ago:
        if(graph.rawData[id].echoTime != nil and me.frameTime - graph.rawData[id].echoTime > me.timeToKeepEchos)
            # Remove the echo memory from the contact;
            radar.rawData[id].echoTime = nil;
        
        # Only keep contacts with echo memory.
        return radar.rawData[id].echoTime != nil;
    },
};