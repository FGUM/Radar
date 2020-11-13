#
# Authors: Axel Paccalin, 5H1N0B1.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Module to filter out targets that the radar is unable to differentiate from the terrain.
# Extends `FGUM.Radar.MOLG.RawFilterExpr` to act as a boolean expression in the modular workflow of filtering contacts.  
#

DopplerFilter = {
    #! \brief   DopplerFilter constructor.
    #! \details Instantiate a new MOLG.Expr to filter contacts according to whether or not the radar can distinguish it from the ground.
    #! \param   minObservedSpeed: The minimum (doppler) speed difference between the terrain and a contact for it to be perceived by the radar (meters/second). 
	new: func (minObservedSpeed) {
        var me = {parents: [DopplerFilter,
                            FGUM_Radar_MOLG.RawFilterExpr.new()]};

		# Minimum observed speed (relative to the ground) for ground target detection. 
		me.minObservedSpeed = minObservedSpeed;
		
		return me;
	},
	
    #! \brief     Check whether a contact can be perceived by the radar.
    #! \overrides MOLG.RawFilterExpr.rawEval(rawData) (pure virtual := nil).
    #! \param     contact: The contact to filter (Contact).
    #! \return    Whether or not the contact is recognized by the filter (boolean).
    rawEval: func(contact){
        # We want to filter out any contact that is under the physical horizon and percieved as moving "like the terrain".
        
        # Get the collision point between the terrain and a aircraft->contact ray.
        var hit = contact.getRayTerrainHit();
        
        # No collision between the observer->contact ray and the terrain means that the contact is above the horizon.
        if(hit == -1)
            return TRUE;
        
        # Test for the type of terrain where the ray hit.
        var geoHit = geo.Coord.new().set_xyz(hit.data[0], hit.data[1], hit.data[2]);
        var geoInfo = geodinfo(geoHit.lat(), geoHit.lon());
        if (geoInfo != nil and geoInfo[1] != nil) 
            # If the ray collision is on water.
            if(geoInfo[1].solid != 1)
                # The radar is able to directly perceive the shape difference between the flat water and the contact.
                return TRUE;
        
        # Get the doppler compression produced by the contact, relative to the doppler compression produced by the terrain.
        var observedSpeed = contact.getVelUVW().orthogonalProjection(contact.getContactRelativePos().normalize());
        
        # If the doppler compression produced by the contact is less than `+/- minObservedSpeed`
        # different than the doppler compression produced by the terrain, the radar won't detect the contact.  
        return math.abs(observedSpeed) > me.minObservedSpeed;
    },
};
