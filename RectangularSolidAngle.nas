#
# Authors: Axel Paccalin, 5H1N0B1.
#
# Version 0.1
#
# Imported under "FGUM_Radar" 
#
# Class to define a rectangular solid angle collision shape.  
#

var Quat = FGUM_LA.Quaternion;

RectangularSolidAngle = {
    #! \brief RectangularSolidAngle constructor.
    #! \param dAlpha: The width of the RSA (radian).
    #! \param dBeta: The height of the RSA (radian).
    #! \param alpha: The vertical center of the RSA (radian).
    #! \param beta: The horizontal center of the RSA (radian).
    new : func(dAlpha, dBeta, alpha=0, beta=0){
        # Ensure positive range for alpha and beta.
        if(dAlpha < 0)
            die("dAlpha must be strictly positive");
        if(dBeta < 0)
            die("dBeta must be strictly positive");
        
        # Initialize the members with pre-computed values, to avoid doing these computation multiple times later. 
        me.dAlphaHalf   = dAlpha / 2;
        me.dBetaHalf    = dBeta  / 2;
        me.orientationC = Quat.fromAxisAngle(Quat.yAxis.data, alpha)
                .quatMult(Quat.fromAxisAngle(Quat.zAxis.data, beta)).conjugate();
                
        return me;
    },
    
    #! \brief  Test whether or not the deviation of an object is inside the RSA.
    #! \param  relativeDeviation: The deviation of an object relative to the neutral position of the RSA (Quaternion).
    #! \return Whether or not the deviation of an object is inside the RSA (boolean).
    collide: func(relativeDeviation){
        var dev = me.orientationC.quatMult(relativeDeviation).toEuler();

        return ((math.abs(dev[1]) < me.dAlphaHalf) and (math.abs(dev[2]) < me.dBetaHalf));
    },
};