#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Module to allow the pilot to filter-out contacts that are beyond a certain range.
# Extends `FGUM.Radar.MOLG.RawFilterExpr` to act as a boolean expression in the modular workflow of filtering contacts.
#

RangeFilter = {    
    #! \brief RangeFilter constructor.
    #! \param maxRange: The maximum range for a contact to be kept (meters).
	new: func (maxRange) {
        var me = {parents: [RangeFilter,
                            FGUM_Radar_MOLG.RawFilterExpr.new()]};

		# Maximum range detection
		me.maxRange = maxRange;
		
		return me;
	},
	
    #! \brief     Check whether a contact is inside the designated range.
    #! \overrides MOLG.RawFilterExpr.rawEval(rawData) (pure virtual := nil).
    #! \param     contact: The contact to filter (Contact).
    #! \return    Whether or not the contact is inside the designated range (boolean).
	rawEval: func(contact){
	    return contact.getRange() <= me.maxRange;
	},
};
