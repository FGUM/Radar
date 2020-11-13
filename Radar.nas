#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Main interface of the FGUM.Radar module.
# Derived from the FGUM_Radar_MOLG.Kernel to behave as a Modular Oriented Logic Graph computational kernel on which we can plug in various modules.
#

Radar = {
    #! \brief Radar constructor.
    #! \param modules : The list of MOLG.Module constituting the radar (Array).
	new: func (modules) {
	    var me = {parents: [Radar, 
	                        FGUM_Radar_MOLG.Kernel.new(modules)]};
	    
        me.tgtContact = nil;  #!< The current selected target.
                
        return me;
	},
};
