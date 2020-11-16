#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Radar_MOLG" 
#
# Module to propagate values through an oriented logic graph, using modular, OOP, and functional paradigms.
# This file defines modules to create rules to compute data on the nodes through the graph.
# It also defines custom expressions to create Booleans Abstract Syntax Trees (BAST) to be evaluated by modules.
# Finally, it defines a computational kernel with sequential rules to coordinate the different modules.
#

var TRUE  = 1;
var FALSE = 0;

# Updatable interface.
Updatable = {
    #! \brief   Virtual member to update between 2 computational frames.
    #! \param   graph: The computational kernel of the Modular Oriented Logic Graph the realization belongs to (MOLG.Kernel).
    #! \param   dt: The time elapsed since the last computational frame (seconds).
    #! \warning Can only be called by one kernel to keep dt consistency.
    #!          Thus limiting the number of `MOLG.Kernel` a single instance of a `MOLG.Module/Expr` can belong to, to 1.
    update: nil,
};

# Computable interface.
Computable = {
    #! \brief   Virtual member to run a computation relative to ONE element of the rawData list.
    #! \detail  Realizations can access `graph.nodesContent['dependency'][id]` (boolean) for any 'dependency' properly declared.
    #!          Realizations can also access `graph.rawData[id]` (<raw data type>) (Updated at each computational frame).
    #! \param   graph: The computational kernel of the Modular Oriented Logic Graph the realization belongs to (MOLG.Kernel). 
    #! \param   id: The index (relative to the rawData list) of the element to compute (string/hash).
    #! \warning Accessing `graph.nodesContent['dependency'][id]` for an undeclared dependency will lead to an incorrect graph or BAST, leading to unpredictable values.
    #!          Accessing `graph.nodesContent['dependency'][id]` or `graph.rawData[id]` with another `id` than the function parameter, will lead to thread concurrency errors.
    compute: nil, 
};

# Evaluable interface.
Evaluable = {
    #! \brief        Virtual member to evaluate a boolean expression relative to ONE element of the rawData list.
    #! \detail       Realizations can access `graph.nodesContent['dependency'][id]` (boolean) for any 'dependency' properly declared.
    #!               Realizations can also access `graph.rawData[id]` (<raw data type>) (Updated at each computational frame).
    #! \param graph: The computational kernel of the Modular Oriented Logic Graph the realization belongs to (MOLG.Kernel). 
    #! \param    id: The index (relative to the rawData list) of the element to compute (string/hash).
    #! \return       The evaluation relative to the element of index `id` (boolean).
    #! \warning      Accessing `graph.nodesContent['dependency'][id]` for an undeclared dependency will lead to an incorrect graph or BAST, leading to unpredictable values.
    #!               Accessing `graph.nodesContent['dependency'][id]` or `graph.rawData[id]` with another `id` than the function parameter, will lead to thread concurrency errors.
    evaluate: nil, 
};

# Abstract class to compute the propagation of binary data through the Modular Oriented Logic Graph (implemented to work with arrays of data).
Module = {
    #! \brief  MOLG.Module constructor.
    #! \detail Any derived class must affect a boolean value to `graph.nodesContent['output'][id]` for each output of `me.outputs` (constructor param) through the realization of the `Computable` interface.
    #! \param  dependencies: The vector of (string/hash) node indices needed for the computation of the module (std.vector).
    #! \param  outputs: The vector of (string/hash) node indices that the module will provide (std.vector)..
    new: func(dependencies=nil, outputs=nil) {
        var me = {parents: [Module,
                            Updatable,     # Derived classes can be realization of `Updatable`.
                            Computable]};  # Derived classes can be realization of `Computable`.
        
        me.dependencies = dependencies != nil ? dependencies : std.Vector.new();  #!< std.vector of (textual/hash) MOLG nodes indices the Module is depending on for computation.
        me.outputs      = outputs      != nil ? outputs      : std.Vector.new();  #!< std.vector of (textual/hash) MOLG nodes indices the module is providing through computation.

        return me;
    },
};

# MOLG.Module Affecting the binary value of a MOLG node with the evaluation of a MOLG.Expr.
ExprModule = {
    #! \brief    MOLG.ExprModule constructor.
    #! \realizes MOLG.Updatable.
    #! \realizes MOLG.Computable.
    #! \param    nodeName: The name of the graph node that will be affected with the result of the expression evaluation (string).
    #! \param    expression: The expression to evaluate (MOLG.Expr).
    new: func(nodeName, expression){
        var me = {parents: [ExprModule, 
                            Module.new(expression.dependencies, 
                                       std.Vector.new([nodeName]))]};
        
        me.nodeName   = nodeName;  #!< Name of the node of the MOLG for which the expression is evaluated.
        
        me.expression = expression;
        
        if(expression.update != nil)
            me.update = me.expression.update != nil ? func(graph, dt){me.expression.update(graph, dt)} : nil;   #!< Realize the `Updatable` interface if necessary.
            
        me.compute = func(graph, id){graph.nodesContent[me.nodeName][id] = me.expression.evaluate(graph, id);}; #!< Realize the `Computable` interface.

        return me;
    },
};

# An abstract class for a boolean abstract syntax tree (implemented to work with arrays of data).
Expr = {
    #! \brief MOLG.Expr constructor
    #! \param dependencies: std.vector of (string/hash) node indices needed for the computation of the expression (std.vector).
    new: func(dependencies=nil){
        var me = {parents: [Expr,
                            Updatable,    # Derived classes can be realization of `Updatable`.
                            Evaluable]};  # Derived classes must be realization of `Evaluable`.
        
        me.dependencies = dependencies;  #!< std.vector of MOLG nodes (textual/hash) indices the Expr is depending on for evaluation (nullable).
        
        return me;
    },
};

# A MOLG.Expr directly evaluating the boolean value of a MOLG node.
NodeEvalExpr = {
    #! \brief MOLG.NodeEvalExpr constructor.
    #! \param nodeName: The name of the MOLG node to evaluate (string).
    new: func(nodeName){
        var me = {parents: [NodeEvalExpr, 
                            Expr.new(std.Vector.new([nodeName]))]};
                            
        me.nodeName = nodeName;  #!< The name of the MOLG node to evaluate.

        return me;
    },
    
    #! \brief    Expression evaluation function.
    #! \realizes MOLG.Evaluable (see related doc).
    evaluate: func(graph, id){
        return graph.nodesContent[me.nodeName][id];
    },
};

# An abstract class for raw data evaluation.
RawFilterExpr = {
    #! \brief MOLG.RawFilterExpr constructor.
    new: func(){
        var me = {parents: [RawFilterExpr,
                            Expr.new()]};
        return me;
    },
    
    #! \brief    Expression evaluation function.
    #! \realizes MOLG.Evaluable (see related doc).
    evaluate: func(graph, id){
        return me.rawEval(graph.rawData[id]);
    },
    
    #! \brief  Virtual raw data evaluation function.
    #! \param  rawData: The unique raw data entry to evaluate (RawData entry).
    #! \return The boolean result of the evaluation (boolean).
    rawEval: nil,
};

# An abstract class for the binary node of a boolean abstract syntax tree.
BinaryExpr = {
    #! \brief    MOLG.BinaryExpr constructor.
    #! \realizes MOLG.Update.
    #! \param    left: The left hand side the binary expression (MOLG.Expr).
    #! \param    right: The right hand side the binary expression (MOLG.Expr).
    new: func(left, right) {
        # TODO: Ensure hashmap access is at worst O(log(n)) complexity in nasal and update the following comment accordingly.
        # Use a hashmap that will be converted to a list later (for O(log(n)) complexity of insert(elem, container)). 
        var dependencies = {};
                
        # Add all the left dependencies.
        if(left.dependencies != nil)
            foreach(dep; left.dependencies.vector)
                dependencies[dep] = TRUE;
        # Add all the right dependencies.
        if(right.dependencies != nil)
            foreach(dep; right.dependencies.vector)
                dependencies[dep] = TRUE;
                
        # Convert the hashmap indices to a std.vector.
        dependencies = std.Vector.new(keys(dependencies));
        dependencies = size(dependencies) != 0 ? dependencies : nil;
        
        # Call parent constructor.
        var me = {parents: [BinaryExpr, Expr.new(dependencies)]};
        
        me.left  = left;   #!< The left  expression of the binary expression.
        me.right = right;  #!< The right expression of the binary expression.
        
        # Override update(graph, dt) only if left or right needs update.
        if(left.update != nil or right.update != nil)
            me.update = me.leftRightUpdate;
        
        return me;
    },
    
    #! \brief Update both the left & right expressions between 2 computational frames.
    #! \param graph: The computational kernel of the Modular Oriented Logic Graph the expr belongs to (MOLG.Kernel).
    #! \param dt: The time elapsed since the last computational frame (seconds).
    leftRightUpdate: func(graph, dt){
        # Only update an expr if it has an update member available;
        if(me.left.update != nil)
            me.left.update(graph, dt);
        if(me.right.update != nil)
            me.right.update(graph, dt);
    },
};

# A MOLG.BinaryExpr for the binary and node of a boolean abstract syntax tree.
BAnd = {
    #! \brief MOLG.BAnd constructor.
    #! \param left : The left  hand side the binary expression (MOLG.Expr).
    #! \param right: The right hand side the binary expression (MOLG.Expr).
    new: func(left, right) {
        var me = {parents: [BAnd,
                            BinaryExpr.new(left, right)]};
        return me;
    },
    
    #! \brief    Expression evaluation function.
    #! \realizes MOLG.Evaluable (see related doc).
    #! \returns  Whether (left and right) evaluates to true (boolean).
    evaluate: func(graph, id){
        # Not 100% sure how the NASAL interpreter is evaluating `a() and b()`, so forcing sequential eval.  
        if(me.left.evaluate(graph, id)  == FALSE) 
            return FALSE;
        if(me.right.evaluate(graph, id) == FALSE)
            return FALSE;
            
        return TRUE;
    },
};

# A MOLG.BinaryExpr for the binary or node of a boolean abstract syntax tree.
BOr = {
    #! \brief MOLG.BOr constructor.
    #! \param left : The left  hand side the binary expression (MOLG.Expr).
    #! \param right: The right hand side the binary expression (MOLG.Expr).
    new: func(left, right) {
        var me = {parents: [BAnd,
                            BinaryExpr.new(left, right)]};
                            
        return me;
    },
    
    #! \brief    Expression evaluation function.
    #! \realizes MOLG.Evaluable (see related doc).
    #! \returns  The whether (left or right) evaluates to true (boolean).
    evaluate: func(graph, id){
        # Not 100% sure how the NASAL interpreter is evaluating `a() and b()`, so forcing sequential eval.  
        if(me.left.evaluate(graph, id)  == TRUE) 
            return TRUE;
        if(me.right.evaluate(graph, id) == TRUE)
            return TRUE;
            
        return FALSE;
    },
};

# The computing kernel class of a MOLG. 
Kernel = {
    #! \brief MOLG.Kernel constructor.
    #! \param modules : The list of module constituting the computational kernel (Array).
    new: func(modules) {
        var me = {parents: [Kernel]};
        
        me.rawDataMtx     = thread.newlock();  #!< Mutual exclusion protecting the rawData member;
        me.rawData        = {};                #!< The MOLG root data (dictionary).
        me.nodeList       = [];                #!< The list of available nodes in the graph (array).
        me.nodesContent   = {};                #!< The data of each nodes (dictionary of dictionaries).
        me.moduleLayers   = [];                #!< The layers of modules (array of arrays).
        
        var unknownLayer = modules;
        
        # Build the graph according to the dependencies & outputs of each module.
        while(size(unknownLayer) > 0){
            # Buffers in which we will distribute unknownLayer.
            var currentLayer = [];
            var nextLayers   = [];
            
            # Check which modules have their dependencies satisfied with the modules in the previous layers.
            foreach(var module; unknownLayer)
                if(me.moduleDepSatisfied(module))
                    append(currentLayer, module);
                else
                    append(nextLayers, module);
            
            # Handle unsatisfied dependencies with an exception.
            # TODO: Use sub-graph analysis fo find which dependency is "the most" not satisfied.                    
            if(size(currentLayer) == 0 and size(nextLayers) != 0)
                die("unsatisfied module dependencies");
            
            # Add the current layer to the kernel;
            foreach(var module; currentLayer)
                me.addModuleOutputs(module);
            append(me.moduleLayers, currentLayer);
            
            # Swap the buffers to continue building the next layers of the graph.
            unknownLayer = nextLayers;
        }
        
        me.lastFrame = getprop("sim/time/elapsed-sec");
        
        return me;
    },
    
    setRawData: func(rawData){
        # Make sure a computational frame won't run during the raw data update.
        thread.lock(me.rawDataMtx);
        
        me.rawData = rawData;
        
        # Release the mutex so a computational can happen.
        thread.unlock(me.rawDataMtx);
    },
    
    #! \brief Run a computational frame.
    #! \param rawData: The dictionary of raw data to propagate through the logic graph.
    frame: func(){
        # Compute the time elapsed since the last frame (dt).
        var curFrame = getprop("sim/time/elapsed-sec");
        var dt = curFrame - me.lastFrame;
        me.lastFrame = curFrame;
        
        # Update each module.
        me.update(dt);
        
        # Make sure the raw data is not updated during a computational frame.
        thread.lock(me.rawDataMtx);
        
        # Declare the nodes of the graph.
        me.prepareNodes();
        
        # Compute each rawData element with each module.
        foreach(var i; keys(me.rawData))
            bind(func(){g.compute(i)}, {g: me, i:i})();
        
        # Release the mutex so the raw data can be updated again.
        thread.unlock(me.rawDataMtx);
    },
    
    #! \brief Initialize each graph node.
    prepareNodes: func(){
        # Each node must be declared as a dictionary.
        foreach(var nodeName; me.nodeList){
            me.nodesContent[nodeName] = {};
        }
    },
    
    #! \brief Update the modules.
    #! \param dt: The time elapsed since the last computational frame (seconds).
    update: func(dt){
        # These nested foreach are really just one. The nesting is just a neat solution to guarantee execution order.
        foreach(var layer; me.moduleLayers){
            foreach(var module; layer)
                if(module.update != nil)
                    module.update(me, dt);
        }
    },
    
    #! \brief Run the computation for a specific RawData entry.
    #! \param id: The index of the data entry to run the computation for (string/hash).
    compute: func(id){
        # These nested foreach are really just one. The nesting is just a neat solution to guarantee execution order.
        # There is however a nesting of (dataSize X modules) when considering the definition of `MOLG.Kernel.frame()` which is the only expected call-stack.
        foreach(var layer; me.moduleLayers)
            foreach(var module; layer)
                # TODO: We can eventually run all the computation of a single layer through parallel processing (we cannot parallel process between layers though).
                if(module.compute != nil)
                    module.compute(me, id);
    },
    
    #! \brief  Dependency satisfaction test.
    #! \param  dep: The dependency to be satisfied (string).
    #! \return Whether or not the dependency is satisfied (boolean). 
    depSatisfied: func(dep){
        foreach(var node; me.nodeList)
            if(node == dep)
                return TRUE;
                    
        return FALSE;
    },
    
    #! \brief  Module dependencies satisfaction test.
    #! \param  module: The module which dependencies must be satisfied (MOLG.Module).
    #! \return Whether or not all the dependencies of the module are satisfied (boolean).
    moduleDepSatisfied: func(module){
        foreach(var dep; module.dependencies.vector)
            if(!me.depSatisfied(dep))
                return FALSE;
        
        return TRUE;
    },
    
    #! \brief Add the outputs of a module to the node list of the graph.
    #! \param module: The module which outputs must be added (MOLG.Module).
    addModuleOutputs: func(module){
        foreach(var output; module.outputs.vector){
            foreach(var node; me.nodeList)
                if(output == node)
                    die("Error: Output \"" ~ output ~ "\" already produced by another module");
                
            append(me.nodeList, output);
        }
    },
};
