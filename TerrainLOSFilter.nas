#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Module to filter radar contacts based on line of sight availability.
#
# Inherit from `FGUM.Radar.MOLG.RawFilterExpr` to act as a boolean expression in the modular workflow of filtering contacts.
#

var TRUE  = 1;
var FALSE = 0;

TerrainLOSFilter = {
    #! \brief TerrainLOSFilter constructor.
    new: func () {
		var me = {parents: [TerrainLOSFilter,
		                    FGUM_Radar_MOLG.RawFilterExpr.new()]};
    },
    
    #! \brief     Check whether the line of sight with contact is obstructed by the terrain or not.
    #! \overrides MOLG.RawFilterExpr.rawEval(rawData) (pure virtual := nil).
    #! \param     contact: The contact to filter (Contact).
    #! \return    Whether the line of sight with contact is obstructed by the terrain or not (boolean).
    rawEval: func(contact){
        var myAlt  = contact.observer.getPosGeo().alt();
        var tgtAlt = contact.getPosGeo().alt();
        
        if(myAlt > 8900 and tgtAlt > 8900)
            return TRUE; # both higher than mt. everest
        
        var hit = contact.getRayTerrainHit();
        
        # No intersection => no ground between the radar and the target.
        if (hit == -1)
            return TRUE;  # Clear LOR
            
        # An intersection happened, whe need to check whether it if AFTER or BEFORE the target:
        else {
            var obsPos = contact.observer.getPosXYZ();
            var contactDPos = contact.getDPos();
            
            # Compute the radar-ground distance on the casted ray (keep value squared to avoid sqrt).
            var terrainSqDist = hit.vecSub(obsPos).squaredMagnitude();
            # Compute the radar-contact distance (keep value squared to avoid sqrt).
            var contactSqDist = contactDPos.squaredMagnitude();
            
            # Radar-terrain distance greater than the radar-target distance:
            # => Ray-terrain collision happened AFTER the target.
            if (terrainSqDist >= contactSqDist)
                return TRUE;  # Clear LOR
        }
        
        # There was a ray-terrain collision and it wasn't behind the target.     
        return FALSE;   # Blocked LOR
    },
};
