#
# Authors: Pinto, Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# References: - Formulas: https://www.radartutorial.eu/01.basics/The%20Radar%20Range%20Equation.en.html
#
# Module to filter radar contacts through radar signal strength.
#
# The Antenna class defines universal laws for propagation and reception of electromagnetic waves.
# The SignalFilter class inherit from `FGUM.Radar.MOLG.RawFilterExpr` to act as a boolean expression in the modular workflow of filtering contacts.
#

var Quat = FGUM_LA.Quaternion;

var Database = FGUM_RCSDatabase.Database;

Antenna = {
    #! \brief Antenna constructor.
    #! \param power: The peak power of the antenna (watt).
    #TODO: Check whether formulas are based on PMPO power or RMS power.
    #! \param gain: The gain the antenna (dB).
    #! \param effectiveAperture: The effective aperture of the receiver (meters²).
    #! \param peMin: The minimum received echo power for a contact to be recognized (watt).
    new: func(power, gain, effectiveAperture, peMin){
		var me = {parents: [Antenna]};
        me.power              = power;
        me.gain               = gain;
        me.effectiveAperture  = effectiveAperture;
        
        me.peMin              = peMin;
        
        return me;
    },
    
    #! \brief  Checks whether or not a contact is recognized by the antenna.
    #! \param  contactDist: The distance between the antenna and the contact (meters).
    #! \param  contactRCS: The effective radar cross-section of the contact (meters²).
    #! \return Whether or not a contact is recognized by the antenna (boolean).
    registerEcho: func(contactDist, contactRCS){
        return me.echoPower(contactDist, contactRCS) >= me.peMin;  
    },
    
    #! \brief  Compute the echo power of a contact.
    #! \param  contactDist: The distance between the antenna and the contact (meters).
    #! \param  contactRCS: The effective radar cross-section of the contact (meters²).
    #! \return The echo power of a contact (watt).
    echoPower: func(contactDist, contactRCS){
        # The factor representing power loss due to the distance. Computed here because it is used 2 times (signal round trip).
        var pdf = me.powerDensityFactor(contactDist);
        
        # Compute the power of the echo as perceived by the receiving antenna.
        return me.power               # Power of the emitter.
             * pdf * me.gain          # Power density at the target.
             * contactRCS             # Power reflected by the target.
             * pdf                    # Power density of the echo hitting the antenna.
             * me.effectiveAperture;  # Power measured by the antenna.
    },
    
    #! \brief  Compute the factor representing the loss of power density of an electromagnetic wave over a certain distance.
    #! \param  contactDist: The distance between the antenna and the contact (meters).
    #! \return The factor representing the loss of power density of an electromagnetic wave over a certain distance (ratio).
    powerDensityFactor: func(dist){
        return 1 / (4 * math.pi * math.pow(dist, 2));
    },
    
    
    #! \brief  Generate an antenna with arbitrary power, gain and effective area values.
    #! \detail Most detection ranges are for a target that has an rcs of 5m², so leave that at default if not specified by source material.
    #! \param  maxDist: The maximum distance at which a contact of a specific RCS will be detected (meters).
    #! \param  rcsOfMaxRange: The specific RCS of the contact related to this range (meters²).
    #! \return The antenna instance (Antenna).
    fromArbitraryPGEA: func(maxDist, rcsOfMaxRange=5){
        var power = 3000;                               # 3KW arbitrary PMPO power.
        var gain  = 30;                                 # 30dB arbitrary gain.
        var effAp = math.pi * math.pow(0.5, 2) * 0.65;  # Arbitrary effective surface of a 1m diameter antenna with 0.65 efficiency.
        
        var peMin = Antenna.computePEMin(power, gain, effAp, maxDist, rcsOfMaxRange);
        
        return Antenna.new(power, gain, effAp, peMin);
    },   
    
    #! \brief  Generate an antenna with arbitrary gain and effective area values.
    #! \detail Most detection ranges are for a target that has an rcs of 5m², so leave that at default if not specified by source material.
    #! \param  power: The power of the antenna (watt).
    #! \param  maxDist: The maximum distance at which a contact of a specific RCS will be detected (meters).
    #! \param  rcsOfMaxRange: The specific RCS of the contact related to this range (meters²).
    #! \return The antenna instance (Antenna).
    fromArbitraryGEA: func(power, maxDist, rcsOfMaxRange=5){
        var gain  = 30;                                 # 30dB arbitrary gain.
        var effAp = math.pi * math.pow(0.5, 2) * 0.65;  # Effective surface of a 1m diameter antenna with 0.65 efficiency.
        
        var peMin = Antenna.computePEMin(power, gain, effAp, maxDist, rcsOfMaxRange);
        
        return Antenna.new(power, gain, effAp, peMin);
    },
    
    
    #! \brief  Compute the minimum peMin necessary to detect a target under specific circumstances.
    #! \detail Most detection ranges are for a target that has an rcs of 5m², so leave that at default if not specified by source material.
    #! \param  power: The power of the antenna (watt).
    #! \param  gain: The gain of the antenna (dB).
    #! \param  effectiveAperture: The effective aperture of the receiver (meters²).
    #! \param  maxDist: The maximum distance at which a contact of a specific RCS will be detected (meters).
    #! \param  rcsOfMaxRange: The specific RCS of the contact related to this range (meters²).
    #! \return The minimum peMin necessary to detect a target of "rcsOfMaxRange" RCS at "maxDist" (watt).
    computePEMin: func(power, gain, effectiveAperture, maxDist, rcsOfMaxRange=5){
        return power 
             * rcsOfMaxRange
             / (math.pow(4 * math.pi, 2) * math.pow(maxDist, 4))
             * gain
             * effectiveAperture;
    },
};


SignalFilter = {
    #! \brief SignalFilter constructor.
    #! \param antenna: The antenna that processes the signal (Antenna).
    new: func(antenna){
		var me = {parents: [SignalFilter,
		                    FGUM_Radar_MOLG.RawFilterExpr.new()]};
		                    
        me.antenna = antenna;
        
        return me;
    },
    
    #! \brief     Check whether a contact is recognized by the antenna.
    #! \overrides MOLG.RawFilterExpr.rawEval(rawData) (pure virtual := nil).
    #! \param     contact: The contact to filter (Contact).
    #! \return    Whether or not the contact is recognized by the antenna (boolean).
    rawEval: func(contact){
        var model = contact.model;
        
        # Get the RCS of the contact (viewed from the front).
        var rcs = contains(Database, model) ? Database[model]
                                            : Database["default"];
        
        # Get the RCS of the contact (viewed from the radar).
        rcs = me.getRCS(contact.getDPos(), contact.getOrientation(), rcs);
        
        return me.antenna.registerEcho(contact.getRange(), rcs);
    },
    
    #! \brief  Compute the RCS of a contact when viewed from the radar position.
    #! \param  dPos: The pos of the contact relative to the radar in the geocentric referential (Vector).
    #! \param  orientation: The orientation of the contact in the geocentric referential (Quaternion).
    #! \return The RCS of the contact when viewed from the radar position (meters²).
    getRCS: func (dPos, orientation, frontRCS){
        var sideRCSFactor  = 2.50;
        var rearRCSFactor  = 1.75;
        var bellyRCSFactor = 3.50;
        
        # Euler angles of the orientation of the target relative to the orientation of the beam.
        var angles = Quat.fromDirection(dPos.data)
                         .conjugate()
                         .quatMult(orientation)
                         .toEuler();
                               
        # Pre-compute to avoid multiple computation later.
        var absCosR = math.abs(math.cos(angles[0]));
        var absSinR = math.abs(math.sin(angles[0]));
        
        # TODO: Check whether toEuler() provide -PI <= yaw <= PI or 0 <= yaw <= 2*PI;
        # Compute the RCS aspect viewed from the beam (The absolute values are preventing us to use linear algebra rotations). 
        return math.cos(angles[1]) * (  math.abs(math.cos(angles[2])) * (math.abs(angles[2]) < math.pi/2 ? rearRCSFactor : 1)
                                      + math.abs(math.sin(angles[2])) * (  sideRCSFactor  * absCosR
                                                                         + bellyRCSFactor * absSinR))
             + math.sin(angles[1]) * (  bellyRCSFactor * absCosR 
                                      + sideRCSFactor  * absSinR);
    },
};
