//Use this only for things that aren't a subtype of obj/machinery/power
//For things that are, override "should_have_node()" on them
GLOBAL_LIST_INIT(wire_node_generating_types, typecacheof(list(/obj/structure/grille)))

#define UNDER_SMES -1
#define UNDER_TERMINAL 1

///////////////////////////////
//CABLE STRUCTURE
///////////////////////////////
////////////////////////////////
// Definitions
////////////////////////////////
/obj/structure/cable
	name = "power cable"
	desc = "A flexible, superconducting insulated cable for heavy-duty power transfer."
	icon = 'icons/obj/power_cond/cable.dmi'
	icon_state = "1-2-4-8"
	level = 1 //is underfloor
	layer = WIRE_LAYER //Above hidden pipes, GAS_PIPE_HIDDEN_LAYER
	anchored = TRUE
	obj_flags = CAN_BE_HIT | ON_BLUEPRINTS
	var/linked_dirs = 0 //bitflag
	var/node = FALSE //used for sprites display
	var/datum/powernet/powernet

/obj/structure/cable/Initialize(mapload, param_color)
	. = ..()

	var/turf/T = get_turf(src)			// hide if turf is not intact
	if(level==1)
		hide(T.intact)
	GLOB.cable_list += src //add it to the global cable list
	connect_wire()

/obj/structure/cable/proc/connect_wire(clear_before_updating = FALSE)
	var/under_thing = NONE
	if(clear_before_updating)
		linked_dirs = 0
	for(var/obj/machinery/power/P in loc)
		if(istype(P, /obj/machinery/power/terminal))
			under_thing = UNDER_TERMINAL
			break
		if(istype(P, /obj/machinery/power/smes))
			under_thing = UNDER_SMES
			break
	for(var/check_dir in GLOB.cardinals)
		var/TB = get_step(src, check_dir)
		if(under_thing)
			var/search_target
			switch(under_thing)
				if(UNDER_SMES)
					search_target = /obj/machinery/power/terminal
				if(UNDER_TERMINAL)
					search_target = /obj/machinery/power/smes
			if(locate(search_target) in TB)
				continue
		var/inverse = turn(check_dir, 180)
		for(var/obj/structure/cable/C in TB)
			linked_dirs |= check_dir
			C.linked_dirs |= inverse
			C.update_icon()

	update_icon()

/obj/structure/cable/Destroy()					// called when a cable is deleted
	//Clear the linked indicator bitflags
	for(var/check_dir in GLOB.cardinals)
		var/inverse = turn(check_dir, 180)
		if(linked_dirs & check_dir)
			var/TB = get_step(loc, check_dir)
			var/obj/structure/cable/C = locate(/obj/structure/cable) in TB
			C.linked_dirs &= ~inverse
			C.update_icon()

	if(powernet)
		cut_cable_from_powernet()				// update the powernets
	GLOB.cable_list -= src							//remove it from global cable list
<<<<<<< HEAD
=======

>>>>>>> 65e9888fa6... [READY] Smart Cables (#44265)
	return ..()									// then go ahead and delete the cable

/obj/structure/cable/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
<<<<<<< HEAD
		var/turf/T = loc
		stored.forceMove(T)
=======
		new /obj/item/stack/cable_coil(get_turf(loc), 1)
>>>>>>> 65e9888fa6... [READY] Smart Cables (#44265)
	qdel(src)

///////////////////////////////////
// General procedures
///////////////////////////////////

//If underfloor, hide the cable
/obj/structure/cable/hide(i)
	if(level == 1 && isturf(loc))
		invisibility = i ? INVISIBILITY_MAXIMUM : 0
	update_icon()

/obj/structure/cable/update_icon()
	if(!linked_dirs)
		icon_state = "noconnection"
	else
		var/list/dir_icon_list = list()
		for(var/check_dir in GLOB.cardinals)
			if(linked_dirs & check_dir)
				dir_icon_list += "[check_dir]"
		var/dir_string = dir_icon_list.Join("-")
		if(dir_icon_list.len > 1)
			for(var/obj/O in loc)
				if(GLOB.wire_node_generating_types[O.type])
					dir_string = "[dir_string]-node"
					break
				else if(istype(O, /obj/machinery/power))
					var/obj/machinery/power/P = O
					if(P.should_have_node())
						dir_string = "[dir_string]-node"
						break
		icon_state = dir_string
	

/obj/structure/cable/proc/handlecable(obj/item/W, mob/user, params)
	var/turf/T = get_turf(src)
	if(T.intact)
		return
	if(W.tool_behaviour == TOOL_WIRECUTTER)
		if (shock(user, 50))
			return
		user.visible_message("[user] cuts the cable.", "<span class='notice'>You cut the cable.</span>")
		investigate_log("was cut by [key_name(usr)] in [AREACOORD(src)]", INVESTIGATE_WIRES)
		deconstruct()
		return

	else if(W.tool_behaviour == TOOL_MULTITOOL)
		if(powernet && (powernet.avail > 0))		// is it powered?
			to_chat(user, "<span class='danger'>Total power: [DisplayPower(powernet.avail)]\nLoad: [DisplayPower(powernet.load)]\nExcess power: [DisplayPower(surplus())]</span>")
		else
			to_chat(user, "<span class='danger'>The cable is not powered.</span>")
		shock(user, 5, 0.2)

	add_fingerprint(user)

// Items usable on a cable :
//   - Wirecutters : cut it duh !
//   - Multitool : get the power currently passing through the cable
//
/obj/structure/cable/attackby(obj/item/W, mob/user, params)
	handlecable(W, user, params)


// shock the user with probability prb
/obj/structure/cable/proc/shock(mob/user, prb, siemens_coeff = 1)
	if(!prob(prb))
		return FALSE
	if(electrocute_mob(user, powernet, src, siemens_coeff))
		do_sparks(5, TRUE, src)
		return TRUE
	else
		return FALSE

/obj/structure/cable/singularity_pull(S, current_size)
	..()
	if(current_size >= STAGE_FIVE)
		deconstruct()

////////////////////////////////////////////
// Power related
///////////////////////////////////////////

// All power generation handled in add_avail()
// Machines should use add_load(), surplus(), avail()
// Non-machines should use add_delayedload(), delayed_surplus(), newavail()

/obj/structure/cable/proc/add_avail(amount)
	if(powernet)
		powernet.newavail += amount

/obj/structure/cable/proc/add_load(amount)
	if(powernet)
		powernet.load += amount

/obj/structure/cable/proc/surplus()
	if(powernet)
		return CLAMP(powernet.avail-powernet.load, 0, powernet.avail)
	else
		return 0

/obj/structure/cable/proc/avail()
	if(powernet)
		return powernet.avail
	else
		return 0

/obj/structure/cable/proc/add_delayedload(amount)
	if(powernet)
		powernet.delayedload += amount

/obj/structure/cable/proc/delayed_surplus()
	if(powernet)
		return CLAMP(powernet.newavail - powernet.delayedload, 0, powernet.newavail)
	else
		return 0

/obj/structure/cable/proc/newavail()
	if(powernet)
		return powernet.newavail
	else
		return 0

/////////////////////////////////////////////////
// Cable laying helpers
////////////////////////////////////////////////

// merge with the powernets of power objects in the given direction
/obj/structure/cable/proc/mergeConnectedNetworks(direction)

	var/inverse_dir = (!direction)? 0 : turn(direction, 180) //flip the direction, to match with the source position on its turf

	var/turf/TB  = get_step(src, direction)

	for(var/obj/structure/cable/C in TB)
		if(!C)
			continue

		if(src == C)
			continue

		if(C.linked_dirs & inverse_dir) //we've got a matching cable in the neighbor turf
			if(!C.powernet) //if the matching cable somehow got no powernet, make him one (should not happen for cables)
				var/datum/powernet/newPN = new()
				newPN.add_cable(C)

			if(powernet) //if we already have a powernet, then merge the two powernets
				merge_powernets(powernet, C.powernet)
			else
				C.powernet.add_cable(src) //else, we simply connect to the matching cable powernet

// merge with the powernets of power objects in the source turf
/obj/structure/cable/proc/mergeConnectedNetworksOnTurf()
	var/list/to_connect = list()
	node = FALSE

	if(!powernet) //if we somehow have no powernet, make one (should not happen for cables)
		var/datum/powernet/newPN = new()
		newPN.add_cable(src)

	//first let's add turf cables to our powernet
	//then we'll connect machines on turf where a cable is present
	for(var/atom/movable/AM in loc)
		if(istype(AM, /obj/machinery/power/apc))
			var/obj/machinery/power/apc/N = AM
			if(!N.terminal)
				continue // APC are connected through their terminal

			if(N.terminal.powernet == powernet) //already connected
				continue

			to_connect += N.terminal //we'll connect the machines after all cables are merged

		else if(istype(AM, /obj/machinery/power)) //other power machines
			var/obj/machinery/power/M = AM

			if(M.powernet == powernet)
				continue

			to_connect += M //we'll connect the machines after all cables are merged

	//now that cables are done, let's connect found machines
	for(var/obj/machinery/power/PM in to_connect)
		node = TRUE
		if(!PM.connect_to_network())
			PM.disconnect_from_network() //if we somehow can't connect the machine to the new powernet, remove it from the old nonetheless

//////////////////////////////////////////////
// Powernets handling helpers
//////////////////////////////////////////////

//if powernetless_only = 1, will only get connections without powernet
//ignore_dir makes sure that connections coming from that direction are ignored
/obj/structure/cable/proc/get_connections(powernetless_only = FALSE, ignore_dir = null)
	. = list()	// this will be a list of all connected power objects
	var/turf/T

	for(var/check_dir in GLOB.cardinals)
		if(linked_dirs & check_dir && check_dir != ignore_dir)
			T = get_step(src, check_dir)
			if(T)
				. |= power_list(T, src, powernetless_only)

	. |= power_list(loc, src, powernetless_only) //get on turf matching cables

/obj/structure/cable/proc/auto_propogate_cut_cable(obj/O)
	if(O && !QDELETED(O))
		var/datum/powernet/newPN = new()// creates a new powernet...
		propagate_network(O, newPN)//... and propagates it to the other side of the cable

//Makes a new network for the cable and propgates it.
//If it finds another network in the process, aborts and uses that one and propogates off of it instead
/obj/structure/cable/proc/propogate_if_no_network()
	if(powernet)
		return
	var/datum/powernet/newPN = new()
	propagate_network(src, newPN, TRUE)

// cut the cable's powernet at this cable and updates the powergrid
/obj/structure/cable/proc/cut_cable_from_powernet(remove = TRUE)
	if(!powernet)
		return

	var/turf/T1 = loc
	var/list/P_list
	if(!T1)
		return
	for(var/dir_check in GLOB.cardinals)
		if(linked_dirs & dir_check)
			T1 = get_step(T1, dir_check)
			P_list += power_list(T1, src, FALSE, TRUE)	// what adjacently joins on to cut cable...

	P_list += power_list(loc, src, FALSE, TRUE)//... and on turf


	if(P_list.len == 0)//if nothing in both list, then the cable was a lone cable, just delete it and its powernet
		powernet.remove_cable(src)

		for(var/obj/machinery/power/P in T1)//check if it was powering a machine
			if(!P.connect_to_network()) //can't find a node cable on a the turf to connect to
				P.disconnect_from_network() //remove from current network (and delete powernet)
		return
	
	// remove the cut cable from its turf and powernet, so that it doesn't get count in propagate_network worklist
	if(remove)
		moveToNullspace()
	powernet.remove_cable(src) //remove the cut cable from its powernet

	var/first = TRUE
	var/delay = 0
	for(var/obj/O in P_list)
		if(first)
			first = FALSE
			continue
		addtimer(CALLBACK(O, .proc/auto_propogate_cut_cable, O), delay) //so we don't rebuild the network X times when singulo/explosion destroys a line of X cables
		delay += 5

///////////////////////////////////////////////
// The cable coil object, used for laying cable
///////////////////////////////////////////////

////////////////////////////////
// Definitions
////////////////////////////////

GLOBAL_LIST_INIT(cable_coil_recipes, list (new/datum/stack_recipe("cable restraints", /obj/item/restraints/handcuffs/cable, 15)))

/obj/item/stack/cable_coil
	name = "cable coil"
	custom_price = 15
	gender = NEUTER //That's a cable coil sounds better than that's some cable coils
	icon = 'icons/obj/power.dmi'
	icon_state = "coil"
	item_state = "coil"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	max_amount = MAXCOIL
	amount = MAXCOIL
	merge_type = /obj/item/stack/cable_coil // This is here to let its children merge between themselves
	item_color = "red"
	desc = "A coil of insulated power cable."
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	throw_speed = 3
	throw_range = 5
	materials = list(MAT_METAL=10, MAT_GLASS=5)
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	attack_verb = list("whipped", "lashed", "disciplined", "flogged")
	singular_name = "cable piece"
	full_w_class = WEIGHT_CLASS_SMALL
	grind_results = list(/datum/reagent/copper = 2) //2 copper per cable in the coil
	usesound = 'sound/items/deconstruct.ogg'

/obj/item/stack/cable_coil/cyborg
	is_cyborg = 1
	materials = list()
	cost = 1

/obj/item/stack/cable_coil/cyborg/attack_self(mob/user)
	var/cable_color = input(user,"Pick a cable color.","Cable Color") in list("red","yellow","green","blue","pink","orange","cyan","white")
	item_color = cable_color
	update_icon()

/obj/item/stack/cable_coil/suicide_act(mob/user)
	if(locate(/obj/structure/chair/stool) in get_turf(user))
		user.visible_message("<span class='suicide'>[user] is making a noose with [src]! It looks like [user.p_theyre()] trying to commit suicide!</span>")
	else
		user.visible_message("<span class='suicide'>[user] is strangling [user.p_them()]self with [src]! It looks like [user.p_theyre()] trying to commit suicide!</span>")
	return(OXYLOSS)

/obj/item/stack/cable_coil/Initialize(mapload, new_amount = null)
	. = ..()
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()
	recipes = GLOB.cable_coil_recipes

///////////////////////////////////
// General procedures
///////////////////////////////////


//you can use wires to heal robotics
/obj/item/stack/cable_coil/attack(mob/living/carbon/human/H, mob/user)
	if(!istype(H))
		return ..()

	var/obj/item/bodypart/affecting = H.get_bodypart(check_zone(user.zone_selected))
	if(affecting && affecting.status == BODYPART_ROBOTIC)
		if(user == H)
			user.visible_message("<span class='notice'>[user] starts to fix some of the wires in [H]'s [affecting.name].</span>", "<span class='notice'>You start fixing some of the wires in [H == user ? "your" : "[H]'s"] [affecting.name].</span>")
			if(!do_mob(user, H, 50))
				return
		if(item_heal_robotic(H, user, 0, 15))
			use(1)
		return
	else
		return ..()


/obj/item/stack/cable_coil/update_icon()
	icon_state = "[initial(item_state)][amount < 3 ? amount : ""]"
	name = "cable [amount < 3 ? "piece" : "coil"]"

//add cables to the stack
/obj/item/stack/cable_coil/proc/give(extra)
	if(amount + extra > max_amount)
		amount = max_amount
	else
		amount += extra
	update_icon()



///////////////////////////////////////////////
// Cable laying procedures
//////////////////////////////////////////////

/obj/item/stack/cable_coil/proc/get_new_cable(location)
	var/path = /obj/structure/cable
	return new path(location, item_color)

// called when cable_coil is clicked on a turf
/obj/item/stack/cable_coil/proc/place_turf(turf/T, mob/user, dirnew)
	if(!isturf(user.loc))
		return

	if(!isturf(T) || T.intact || !T.can_have_cabling())
		to_chat(user, "<span class='warning'>You can only lay cables on catwalks and plating!</span>")
		return

	if(get_amount() < 1) // Out of cable
		to_chat(user, "<span class='warning'>There is no cable left!</span>")
		return
	
	if(get_dist(T,user) > 1) // Too far
		to_chat(user, "<span class='warning'>You can't lay cable at a place that far away!</span>")
		return

	if(is_type_in_list(/obj/structure/cable, T.contents))
		to_chat(user, "<span class='warning'>There's already a cable at that position!</span>")
		return

	var/obj/structure/cable/C = get_new_cable(T)

	//create a new powernet with the cable, if needed it will be merged later
	var/datum/powernet/PN = new()
	PN.add_cable(C)

	for(var/dir_check in GLOB.cardinals)
		C.mergeConnectedNetworks(dir_check) //merge the powernet with adjacents powernets
	C.mergeConnectedNetworksOnTurf() //merge the powernet with on turf powernets

	use(1)

	if(C.shock(user, 50))
		if(prob(50)) //fail
			new /obj/item/stack/cable_coil(get_turf(C), 1)
			C.deconstruct()

	return C

<<<<<<< HEAD
// called when cable_coil is click on an installed obj/cable
// or click on a turf that already contains a "node" cable
/obj/item/stack/cable_coil/proc/cable_join(obj/structure/cable/C, mob/user, var/showerror = TRUE)
	var/turf/U = user.loc
	if(!isturf(U))
		return

	var/turf/T = C.loc

	if(!isturf(T) || T.intact)		// sanity checks, also stop use interacting with T-scanner revealed cable
		return

	if(get_dist(C, user) > 1)		// make sure it's close enough
		to_chat(user, "<span class='warning'>You can't lay cable at a place that far away!</span>")
		return


	if(U == T) //if clicked on the turf we're standing on, try to put a cable in the direction we're facing
		place_turf(T,user)
		return

	var/dirn = get_dir(C, user)

	// one end of the clicked cable is pointing towards us
	if(C.d1 == dirn || C.d2 == dirn)
		if(!U.can_have_cabling())						//checking if it's a plating or catwalk
			if (showerror)
				to_chat(user, "<span class='warning'>You can only lay cables on catwalks and plating!</span>")
			return
		if(U.intact)						//can't place a cable if it's a plating with a tile on it
			to_chat(user, "<span class='warning'>You can't lay cable there unless the floor tiles are removed!</span>")
			return
		else
			// cable is pointing at us, we're standing on an open tile
			// so create a stub pointing at the clicked cable on our tile

			var/fdirn = turn(dirn, 180)		// the opposite direction

			for(var/obj/structure/cable/LC in U)		// check to make sure there's not a cable there already
				if(LC.d1 == fdirn || LC.d2 == fdirn)
					if (showerror)
						to_chat(user, "<span class='warning'>There's already a cable at that position!</span>")
					return

			var/obj/structure/cable/NC = get_new_cable (U)

			NC.d1 = 0
			NC.d2 = fdirn
			NC.add_fingerprint(user)
			NC.update_icon()

			//create a new powernet with the cable, if needed it will be merged later
			var/datum/powernet/newPN = new()
			newPN.add_cable(NC)

			NC.mergeConnectedNetworks(NC.d2) //merge the powernet with adjacents powernets
			NC.mergeConnectedNetworksOnTurf() //merge the powernet with on turf powernets

			if(NC.d2 & (NC.d2 - 1))// if the cable is layed diagonally, check the others 2 possible directions
				NC.mergeDiagonalsNetworks(NC.d2)

			use(1)

			if (NC.shock(user, 50))
				if (prob(50)) //fail
					NC.deconstruct()

			return

	// exisiting cable doesn't point at our position, so see if it's a stub
	else if(C.d1 == 0)
							// if so, make it a full cable pointing from it's old direction to our dirn
		var/nd1 = C.d2	// these will be the new directions
		var/nd2 = dirn


		if(nd1 > nd2)		// swap directions to match icons/states
			nd1 = dirn
			nd2 = C.d2


		for(var/obj/structure/cable/LC in T)		// check to make sure there's no matching cable
			if(LC == C)			// skip the cable we're interacting with
				continue
			if((LC.d1 == nd1 && LC.d2 == nd2) || (LC.d1 == nd2 && LC.d2 == nd1) )	// make sure no cable matches either direction
				if (showerror)
					to_chat(user, "<span class='warning'>There's already a cable at that position!</span>")

				return


		C.update_icon()

		C.d1 = nd1
		C.d2 = nd2

		//updates the stored cable coil
		C.update_stored(2, item_color)

		C.add_fingerprint(user)
		C.update_icon()


		C.mergeConnectedNetworks(C.d1) //merge the powernets...
		C.mergeConnectedNetworks(C.d2) //...in the two new cable directions
		C.mergeConnectedNetworksOnTurf()

		if(C.d1 & (C.d1 - 1))// if the cable is layed diagonally, check the others 2 possible directions
			C.mergeDiagonalsNetworks(C.d1)

		if(C.d2 & (C.d2 - 1))// if the cable is layed diagonally, check the others 2 possible directions
			C.mergeDiagonalsNetworks(C.d2)

		use(1)

		if (C.shock(user, 50))
			if (prob(50)) //fail
				C.deconstruct()
				return

		C.denode()// this call may have disconnected some cables that terminated on the centre of the turf, if so split the powernets.
		return

//////////////////////////////
// Misc.
/////////////////////////////

/obj/item/stack/cable_coil/red
	item_color = "red"
	color = "#ff0000"

/obj/item/stack/cable_coil/yellow
	item_color = "yellow"
	color = "#ffff00"

/obj/item/stack/cable_coil/blue
	item_color = "blue"
	color = "#1919c8"

/obj/item/stack/cable_coil/green
	item_color = "green"
	color = "#00aa00"

/obj/item/stack/cable_coil/pink
	item_color = "pink"
	color = "#ff3ccd"

/obj/item/stack/cable_coil/orange
	item_color = "orange"
	color = "#ff8000"

/obj/item/stack/cable_coil/cyan
	item_color = "cyan"
	color = "#00ffff"

/obj/item/stack/cable_coil/white
	item_color = "white"

/obj/item/stack/cable_coil/random
	item_color = null
	color = "#ffffff"


/obj/item/stack/cable_coil/random/five
=======
/obj/item/stack/cable_coil/five
>>>>>>> 65e9888fa6... [READY] Smart Cables (#44265)
	amount = 5

/obj/item/stack/cable_coil/cut
	amount = null
	icon_state = "coil2"

/obj/item/stack/cable_coil/cut/Initialize(mapload)
	. = ..()
	if(!amount)
		amount = rand(1,2)
	pixel_x = rand(-2,2)
	pixel_y = rand(-2,2)
	update_icon()

#undef UNDER_SMES
#undef UNDER_TERMINAL
