#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Module to define a workflow / pipeline to process radar contacts produced by a ContactManager through a MOLG.
#

var TRUE  = 1;
var FALSE = 0;

Pipeline = {
    #! \brief Pipeline constructor.
    #! \param radar: Radar defining the process of filtering contacts (MOLG instance).
    #! \param contactManager: The manager providing all possible contacts (ContactManager instance).
    #! \param frequency: The frequency of the pipeline (Hz).
    new: func(radar, contactManager, frequency){
        var me = {parents: [Pipeline]};
        me.radar = radar;
        
        me.contactManager = contactManager;
        # Timer for the radar clock.
        me.timer = maketimer(1/frequency, me, me.loop);
        # Make the timer follow the time of the simulation (time acceleration, pause ...).
        me.timer.simulatedTime = 1;
        
        # Flag representing whether a loop cycle is running and it's associated R/W mutex.
        me.runningFlagMtx = thread.newlock();
        me.runningFlag    = FALSE;
        
        me.contactManager.setUpdateCallback(bind(func(){p.updateContactDictionary()}, {p:me, debug:debug}));
        
        return me;
    },
    
    #! \brief Starts the processing pipeline.
    start: func(){
        me.timer.start();
    },
    
    #! \brief Run one frame the processing pipeline.
    loop: func(){
        # Skip the frame if a previous computational frame is still running. 
        thread.lock(me.runningFlagMtx);
        if(me.runningFlag){
            thread.unlock(me.runningFlagMtx);
            return;
        }
        
        # Make sure no other computational frames will run in parallel of this one.
        me.runningFlag = TRUE;
        thread.unlock(me.runningFlagMtx);
        
        # Reset the buffers of the contacts & observer
        me.contactManager.resetBuffers();
        me.radar.frame();
        
        # Reset the running flag so that the next computational frame can run. 
        thread.lock(me.runningFlagMtx);
        me.runningFlag = FALSE;
        thread.unlock(me.runningFlagMtx);
    },
    
    #! \brief  Update the contacts of the radar with the contacts in the contact manager.
    #! \detail This is only executed when the update of the dictionary of contacts in the contact manager calls back.
    updateContactDictionary: func(){
        me.radar.setRawData(me.contactManager.contacts);
    },
};
