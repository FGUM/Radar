#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar"
#
# Contact for the Radar modules.
# Derived from the FGUM_Contact.Contact.
#

RadarContact = {
    #! \brief RadarContact constructor.
    #! \param prop: The ai property node the contact is based upon (property-tree node).
    #! \param observer: The observer through which the contact is perceived (AircraftObserver).
	new: func (prop, observer) {
        var me = {parents: [RadarContact,
                            FGUM_Contact.Contact.new(prop, observer)]};

		me.echoTime = nil;  #!< the last time an echo was perceived from the contact.
		
		return me;
	},
};
