#
# Authors: Axel Paccalin, 5H1N0B1.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Module to define the shape of an Active Mechanically Steered Array.
# TODO: Many scan shapes are possible for these radar, so maybe we should rename this file & class to something more specific. 
# This file defines functions to generate collision shapes representing the scan action over time.
# It also defines the rules and meta-parameter structures necessary to compute such shapes.
# 
# Extends `FGUM.Radar.MOLG.RawFilterExpr` to act as a boolean expression in the modular workflow of filtering contacts.  
#
# For now the scan shape is the following:
#  - left to right, right to left, repeat.
#  - up to bottom, repeat. (the cursor jump back to the top once the bottom strip is scanned (not sure it behaves like that IRL)).
#

var RSA = FGUM_Radar.RectangularSolidAngle;

AMSAScanShapeFilter = {
    # Various modes available for the radar.
    MODES: {
        SCAN:      0,  #!< Radar scanning.
        SOFT_LOCK: 1,  #!< TWS mode only. Gives enough info for missiles with data-link like Amraam to be fired. Unlike real lock opponent wont know he is locked (but he wil have regular spikes). Shorter range than real lock.
        HARD_LOCK: 2,  #!< Real lock. Opponent RWR will go off. Fox-1 missiles needs this kind of lock.
    },
    
    
    # Radar controller configuration, will define the size and center offset of the scan area.
    Config: {
        #! \brief AMSAScanShapeFilter.Config constructor.
        #! \param stripCount: The The amount of strips (vertical subdivisions) of the base AMSA radar to be scanned (strict positive integer).
        #! \param stripOffset: The index of the first strip to be scanned (positive integer, top strip starts at 0, higher number means lower first strip).
        #! \param dBeta: The width of the scan (radian).
        #! \param betaOffset: The horizontal position of the center of the scan (radian).
        new: func(stripCount, stripOffset, dBeta, betaOffset){
            var me = {parents: [AMSAScanShapeFilter.Config]};
            
            me.stripCount  = stripCount;
            me.stripOffset = stripOffset;
            me.dBeta       = dBeta;
            me.betaOffset  = betaOffset;
            
            return me;
        },
        
        #! \brief  Equality operator.
        #! \param  other: The AMSAScanShapeFilter.Config instance to compare with.
        #! \return Whether the configs are equal or not (boolean).
        equals: func(other){
            return me.stripCount  == other.stripCount
               and me.stripOffset == other.stripOffset
               and me.dBeta       == other.dBeta
               and me.betaOffset  == other.betaOffset;
        },
    },
    
    
    #! \brief   AMSAScanShapeFilter constructor.
    #! \details Instantiate a new MOLG.Expr to filter contacts according to an AMSA radar scan shape.
    #! \param   stripsQt: The quantity of horizontal strips (vertical subdivisions) of the radar (strict positive integer).
    #! \param   stripsDAlpha: The alpha height of a single strip (radians).
    #! \param   stripsDBeta: The maximum beta width of a single strip (radians).
    #! \param   panRate: The scan angular velocity (radians/seconds).
    #! \param   softRadius: The radius of a soft-lock (radians).
    #! \param   hardRadius: The radius of a hard-lock (radians).
	new: func(stripsQt, stripsDAlpha, stripsDBeta, panRate, softRadius, hardRadius){
        var me = {parents: [AMSAScanShapeFilter, 
                            FGUM_Radar_MOLG.RawFilterExpr.new()]};
        
        me.rectangularSolidAngles = []; 
        
        if(stripsQt < 1)
            die("The array needs at least one strip");
        
        me.stripsQt      = stripsQt;     #!< Amount of horizontal strips in the radar.
        me.stripsDAlpha  = stripsDAlpha; #!< The alpha (radian) difference between 2 strips.
        me.stripsDBeta   = stripsDBeta;  #!< The maximum pan width (radian) of the radar.
        me.panRate       = panRate;      #!< The pan rate (radian/seconds) of the radar.

        me.mode          = AMSAScanShapeFilter.MODES.SCAN;                               #!< Current operating mode of the radar.
        me.scanConfig    = AMSAScanShapeFilter.Config.new(stripsQt, 0, stripsDBeta, 0);  #!< The configuration of the radar when operating in scan mode;     
        me.currentConfig = me.scanConfig;                                                #!< The current configuration of the radar;     
        
        me.softRadius = softRadius;  # The radius to be scanned around the target in soft lock mode  
        me.hardRadius = hardRadius;  # The radius to be scanned around the target in hard lock mode  
        
        me.stripIdx     = 0;  #!< The current strip index.
        me.panPos       = 0;  #!< The current array pan position  ( 0: pan begin, 1: pan end (next strip))
        me.panDirection = 1;  #!< The current array pan direction (-1: to the left,  1: to the right)
        
        me.RSAShape = [];  #!< The collision shape (list of Rectangular Solid Angles) of the radar during the last frame.
        
        return me;
    },
    
    #! \brief     Simulate the whole radar behavior (mode changes / scan shape ...).
    #! \details   Update the members to provide context-based data for the filtering step.
    #! \overrides MOLG.Expr.update(graph, dt) (pure virtual := nil).
    #! \param     radar: The Radar => MOLG.Kernel instance this module belongs to (Radar).
    #! \param     dt: The delta time of the radar to simulate (seconds).
    update: func(radar, dt){
        # Handle configurations
        if (me.mode != AMSAScanShapeFilter.MODES.SCAN and radar.tgtContact != nil){
            me.setConfig(me.genLockConfig(radar.tgtContact.getObserverRelativeDev()));
        } else {# me.mode == AMSAScanShapeFilter.MODES.SCAN or target lost.
            if(!me.currentConfig.equals(me.scanConfig))
                me.setConfig(me.scanConfig);
        }
        me.updateRSAShape(dt);
    },
    
    #! \brief     Check whether a contact is in the collision shape of the radar scan.
    #! \overrides MOLG.RawFilterExpr.rawEval(rawData) (pure virtual := nil).
    #! \param     contact: The contact to filter (Contact).
    #! \return    The boolean flag representing whether or not the contact is recognized by the filter (boolean).
    rawEval: func(contact){
        var relDev = contact.getObserverRelativeDev();
        foreach(var rsa; me.RSAShape.vector)
            if(rsa.collide(relDev))
                return TRUE;
    },
    
    #! \brief   Generate a config to scan the currently locked target, according to the current lock mode.
    #! \details The overall scan shape is a RSA based lockRadius angle around the current target. Angle which is depending on the lock type.
    #!          The RSA shape is bigger than the geometrical minimum to comply with the strips geometry of the array.  
    #! \param   dev: The Quaternion, deviation of the locked target relative to the radar neutral position (Quaternion).
    #! \return  The config representing the scan shape of a lock around the current target (AMSAScanShapeFilter.config).
    genLockConfig: func(dev){
        var angularSize = me.mode == AMSAScanShapeFilter.MODES.HARD_LOCK ? me.hardRadius : me.softRadius;
        
        var dev = dev.toEuler();
        
        # Compute the beta offset and clip it to what is allowed by the radar.
        var betaOffset = dev[2] >= 0 ? 1 : -1                          # The beta deviation direction.
                       * math.min(math.abs(dev[2]),                    # Multiplied by the minimum between the abs beta deviation    
                                  (me.stripsDBeta - angularSize) /2);  # and the maximum allowed beta offset for the current dBeta.


        var maxAlpha = dev[1] + angularSize;
        var minAlpha = dev[1] - angularSize;
                
        # Compute the index of the strip containing the maxAlpha line.
        var minStripIndex = me.stripsDAlpha * ((me.stripsQt-1) / 2) # Alpha of the middle of the highest strip.
                          - maxAlpha;                               # Minus the maximum alpha we have to scan.
        minStripIndex    /= me.stripsDAlpha;                        # Normalized by strip vertical size.    
        minStripIndex     = round(minStripIndex);                   # Rounded to find the closest strip center.
        # Clip the index in the radar FOV.
        if(minStripIndex < 0)
            minStripIndex = 0;
        if(minStripIndex > me.stripsQt)
            minStripIndex = me.stripsQt -1;
        
        # Compute the index of the strip containing the minAlpha line.
        var maxStripIndex  = me.stripsDAlpha * ((me.stripsQt-1) / 2) # Alpha of the middle of the highest strip.
                           - minAlpha;                               # Minus the minimum alpha we have to scan.
        maxStripIndex     /= me.stripsDAlpha;                        # Normalized by strip vertical size.    
        maxStripIndex      = round(minStripIndex);                   # Rounded to find the closest strip center.
        # Clip the index in the radar FOV.
        if(maxStripIndex < 0)
            maxStripIndex = 0;
        if(maxStripIndex > me.stripsQt)
            maxStripIndex = me.stripsQt -1;
        
        # Return a radar config scanning at angularSize radius around the target (the exact surface scanned may vary depending on the number of strips needed). 
        return AMSAScanShapeFilter.Config.new(maxStripIndex - minStripIndex + 1, minStripIndex, angularSize, dev[2]);
    },
    
    #! \brief   Update the current config defining the scan shape of the radar array.
    #! \details The beam will keep it's direction. If it's within the parameter of the new config, it will keep it's angular position, otherwise, it will be clipped. 
    #! \param   config: The new config to set (AMSAScanShapeFilter.config). 
    setConfig : func(config){
        # Compute the current cursor position.
        var curStripIndex = me.stripIdx + me.currentConfig.stripOffset;
        var curPan = (me.panPos - 0.5) * me.currentConfig.dBeta
                   + me.currentConfig.betaOffset;
        
        # Set the new config.
        me.currentConfig = config;
        
        # Compute the current cursor position in the new config referential.
        curStripIndex -= me.currentConfig.stripOffset;
        curPan        -= me.currentConfig.betaOffset;
        curPan        /= me.currentConfig.dBeta;
        curPan        += 0.5;
        
        # Clip the new cursor values to the scan area available in the new config
        if(curStripIndex < 0)
            curStripIndex = 0;
        else if(curStripIndex >= me.currentConfig.stripCount)
            curStripIndex = me.currentConfig.stripCount - 1;
        if(curPan < 0)
            curPan = 0;     
        if(curPan > 1)
            curPan = 1;
        
        # Set the new cursor values
        me.stripIdx = curStripIndex;
        me.panPos   = curPan;
    },
    
    #! \brief   Simulate the cursor movement for a certain amount of time and creates the corresponding Rectangular Solid Angle collision shapes.
    #! \param   dt: The delta time of the radar to simulate (seconds).
    #! \warning Shouldn't be used outside the `update()` call-stack.
    updateRSAShape: func(dt){
        # Compute dt in the strip time referential. 
        var stripDt = dt * me.panRate / me.currentConfig.dBeta;
        
        # If at least one full scan loop happened between this frame and the previous one.
        # This means that we can compute the RSA collision for the whole field of view of the radar (and not slice-by-slice).
        if(stripDt >= me.currentConfig.stripCount){
            # Update the RSA filter with the RSA shape corresponding to the full radar FOV.  
            me.RSAShape = [RSA.new(me.stripsDAlpha * me.currentConfig.stripCount, 
                                   me.currentConfig.dBeta,
                                   me.getStripAlpha(0),
                                   me.currentConfig.betaOffset)];
            # Move the radar cursor to where it should be.
            me.advanceCursor(stripDt);
            # Stop here, as we are already covering all the radar FOV possible.
            return;
        }
        
        # List of RectangularSolidAngles constituting the radar beam collision shape in the last frame. 
        var RSAs = std.Vector.new();
        
        # This loop will only actuate 4 times at worst.
        while(stripDt > 0.0000001){  # Ideally, we'd like to test if stripDt < 0, but floating point calculation errors may cause it to never get there.
            # Get the amount of pan we can still do in the current strip
            var panRemaining = me.panRemaining();
            
            if(panRemaining != 1 or stripDt < 2){
                # We add a small RSA to represent the current strip
                var localStripDt = math.min(stripDt, panRemaining);
                
                # Create the single-strip RSA.
                RSAs.append(RSA.new(me.getStripDAlpha(1), 
                                    me.getStripDBeta(localStripDt),
                                    me.getStripAlpha(me.stripIdx),
                                    me.getStripBeta(localStripDt)));

                stripDt -= localStripDt;
                me.advanceCursor(localStripDt);
            } else {
                # We can make a bigger RSA to combine multiple full strips (to reduce filter runtime).
                # Compute the minimum between the full strips we still need to scan and the full strips are available above, including current (unstarted) strip.
                var stripsQt = math.min(math.floor(stripDt), me.currentConfig.stripCount - me.stripIdx);
                
                # Create the multi-strip RSA.
                RSAs.append(RSA.new(me.getStripDAlpha(stripsQt), 
                                    me.currentConfig.dBeta,
                                    me.getStripAlpha(me.stripIdx) + (1-stripsQt) * me.stripsDAlpha / 2,
                                    me.currentConfig.betaOffset));
                                    
                stripDt -= stripsQt;
                me.advanceCursor(stripsQt);
            }
        }
        
        # Update the RSA filter with the composite RSA shape.
        me.RSAShape = RSAs;
    },
    
    #! \brief   Moves the beta cursor and the alpha index for a stripDt proportion of full strips.
    #! \details This provides the left-right, right-left, left-right... top to bottom behavior. But does NOT create the colliders for it.
    #! \param   stripDt: The portion of a single strip we have to cover (ratio, can be > 1 >= me.panRemaining(), must remain > 0).
    #! \warning Shouldn't be used outside the `updateRSAShape()` call-stack.        
    advanceCursor: func(stripDt){
        # Compute how many full strips have been advanced, solely by the dt input.
        var stripsFinished  = math.floor(stripDt);
        # Compute how much of a strip there is to add after the full strips.
        var stripsRemainder = stripDt - stripsFinished;
        
        # Finishing an n amount of strips where n is an ODD INTEGER will flip both the position of the cursor relative to it's strip and it's direction.
        if(math.mod(stripsFinished, 2)){
            me.panDirection = -me.panDirection;
            me.panPos       = 1 - me.panPos
        }
        
        # If there is more to pan after the full strips completed than there is available on the current strip:
        if(stripsRemainder > me.panRemaining()){
            # Complete the current strip.
            stripsFinished   += 1;
            me.panPos = me.panDirection == 1 ? 1 : 0;
            me.panDirection = - me.panDirection;
            
            # And compute what's left to add (after completion of the current strip).
            stripsRemainder -= me.panRemaining();
        }
        
        # Should never happen but throw error to prevent garbage and help debug potential runtime problems.
        if(stripsRemainder > me.panRemaining())
            die("runtime error");
        
        # Pan for how much of a strip there is to add after the full strips.
        me.panPos += stripsRemainder * me.panDirection;
        
        # Update the current strip index.
        me.stripIdx = math.mod(me.stripIdx + stripsFinished, me.currentConfig.stripCount);
        
        # Bypass any strip remainder that's small enough to be a floating point calculation error.
        if(me.panRemaining() < 0.0000001){
            me.stripIdx = math.mod(me.stripIdx + stripsFinished, me.currentConfig.stripCount);
            me.panPos = me.panDirection == 1 ? 1 : 0;
            me.panDirection = - me.panDirection;
        }
    },
    
    #! \brief   Get the alpha center of the strip at a specific index.
    #! \details The offset is integrated here, so the strip index must be in the local (offset-less) scan referential.
    #! \param   stripIdx: The index of the strip (positive integer).
    #! \return  The alpha center of the strip at the stripIdx (radian).
    getStripAlpha: func(stripIdx){
        return me.stripsDAlpha * (  (me.stripsQt-1) / 2                          # Alpha of the highest strip.
                                  - (me.currentConfig.stripOffset + stripIdx));  # Minus total dAlpha to reach the desired strip.
    },
    
    #! \brief  Get the beta center of the RSA corresponding to the remaining strip.
    #! \param  panRemaining: The ratio of strip we want the RSA to cover (ratio).
    #! \return The beta center of the RSA corresponding to the "panRemaining" next part of strip (radian).
    getStripBeta: func(panRemaining){
        return me.currentConfig.betaOffset + me.currentConfig.dBeta * me.panDirection * (1 - panRemaining) / 2;
    },
    
    #! \brief  Get the delta alpha needed to cover a certain amount of strips.
    #! \param  stripsQt: The amount of strips to cover (positive integer).
    #! \return The delta alpha needed to cover stripsQt strips (radian).
    getStripDAlpha: func(stripsQt){
        return me.stripsDAlpha * stripsQt;
    },
    
    #! \brief  Get the delta beta needed to cover a certain portion of a strip.
    #! \param  panRemaining: The portion of the single strip to cover (ratio).
    #! \return The delta beta needed to cover panRemaining of a strip (radian).
    getStripDBeta: func(panRemaining){
        return panRemaining * me.currentConfig.dBeta;
    },
    
    
    #! \brief  Compute how much pan is remaining on the current strip. 
    #! \return The portion of a single strip we still have to cover (ratio).
    panRemaining: func(){
        return me.panDirection == 1 ? 1 - me.panPos : me.panPos; 
    },
};
