var dialogs =
{
	firetank: gui.Dialog.new("sim/gui/dialogs/firetank/dialog", "Aircraft/DC-10/Systems/firetank-dlg.xml")
};

var delta_time = props.globals.getNode("/sim/time/delta-realtime-sec", 1);

setlistener("/sim/signals/fdm-initialized", func {

    var tankop_timer = maketimer(0.01, func{tank_operations()});

    setlistener("/sim/model/firetank/opentankdoors", func {
        if (getprop("/sim/model/firetank/opentankdoors") and getprop("/sim/model/firetank/enabled")) {
            tankop_timer.start();
        } else {
            tankop_timer.stop();
            setprop("sim/model/firetank/opentankdoors", 0);
            setprop("sim/model/firetank/waterdropretardantctrl", 0);
            setprop("sim/model/firetank/retardantdropparticlectrl", 0);
        }
    });
});

#################### watertank ####################

# 1 Gallon = 8.345404 lbs * 2500 = 20863 lbs

var capacity = 0.0;
var weight = 0.0;
var volume = 0.0;

#optimize using listeners VS loop where possible
var tank_operations = func {

    var paused = getprop("sim/freeze/clock");
    var crashed = getprop("sim/crashed");

    if (crashed or paused) {
        setprop("sim/model/firetank/waterdropparticlectrl", 0);
        setprop("sim/model/firetank/retardantdropparticlectrl", 0);
        return;
    }

    var tankdooropen = getprop("sim/model/firetank/opentankdoors");
    var foam = getprop("sim/model/firetank/foam");
    var hopperweight = getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]");
    var groundspeed = getprop("velocities/groundspeed-kt");
    var airspeed = getprop("velocities/airspeed-kt");
    var particles = getprop("sim/model/DC-10/effects/particles/enabled");
    var altitude = getprop("position/altitude-agl-ft");
    var normalized = 1 - (altitude - 0) / (60 - 0);
    var quantity = getprop("sim/model/firetank/quantity");

    var red_diffuse = getprop("/rendering/scene/diffuse/red");
    setprop("/sim/model/DC-10/effects/particles/redcombined", red_diffuse * .95);
    setprop("/sim/model/DC-10/effects/particles/greencombined", red_diffuse * .98);
    setprop("/sim/model/DC-10/effects/particles/bluecombined", red_diffuse * 1);

    if (foam) {
        setprop("sim/model/firetank/waterdropparticlectrl", tankdooropen * hopperweight * particles);
        setprop("sim/model/firetank/retardantdropparticlectrl", 0);
        setprop("/sim/model/DC-10/effects/particles/redcombined", red_diffuse * .95);
        setprop("/sim/model/DC-10/effects/particles/greencombined", red_diffuse * .98);
        setprop("/sim/model/DC-10/effects/particles/bluecombined", red_diffuse * 1);
    } else {
        setprop("sim/model/firetank/retardantdropparticlectrl", tankdooropen * hopperweight * particles);
        setprop("sim/model/firetank/waterdropparticlectrl", 0);
        setprop("/sim/model/DC-10/effects/particles/redcombined", red_diffuse * .89);
        setprop("/sim/model/DC-10/effects/particles/greencombined", red_diffuse * .35);
        setprop("/sim/model/DC-10/effects/particles/bluecombined", red_diffuse * .13);
    }

    if (tankdooropen and hopperweight) {

		#water = 12000 gal * 8.34 weight per gal = 100080 lb / 8 sec dump = 12510 lb per sec / 100 (.01 seconds timer cycle) = 125.1 lb capacity per cycle
		#retardant = 12000 gal * 8.87 weight per gal = 106440 lb / 8 sec dump = 13305 lb per sec / 100 (.01 seconds timer cycle) = 133.05 lb capacity per cycle

        if (foam) {
            capacity = 125.1 * 7;
            if (quantity == 1) weight = 25020;
				else if (quantity == 2) weight = 50040;
					else if (quantity == 3) weight = 75060;
						else if (quantity == 4) weight = 100080;
        } else {
            capacity = 133.05 * 7;
            if (quantity == 1) weight = 26610;
				else if (quantity == 2) weight = 53220;
					else if (quantity == 3) weight = 79830;
						else if (quantity == 4) weight = 106440;
        }
        setprop("sim/model/firetank/droprate", 400);

        if (volume < weight) {
            volume += capacity;
            hopperweight -= capacity;

            if (hopperweight < 10) {
                volume = 0;
                hopperweight = 0;
                setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]", 0);
                setprop("sim/model/firetank/opentankdoors", 0);
				setprop("sim/model/firetank/retardantdropparticlectrl", 0);
				setprop("sim/model/firetank/waterdropparticlectrl", 0);
            } else {
                setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]", hopperweight);
            }
        } else {
			setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]", 0);
            setprop("sim/model/firetank/opentankdoors", 0);
            setprop("sim/model/firetank/retardantdropparticlectrl", 0);
            setprop("sim/model/firetank/waterdropparticlectrl", 0);
            volume = 0;
			hopperweight = 0;
        }
    }

    if (hopperweight <= 0 or getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]") <= 0) {
        volume = 0;
        hopperweight = 0;
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[6]", 0);
        setprop("sim/model/firetank/opentankdoors", 0);
    }

    if (tankdooropen and hopperweight) {
		if (foam)
			setprop("sim/model/firetank/waterdropparticlectrl", 1);
		else
			setprop("sim/model/firetank/retardantdropparticlectrl", 1);
		
    } else {
        setprop("sim/model/firetank/retardantdropparticlectrl", 0);
		setprop("sim/model/firetank/waterdropparticlectrl", 0);
    }

    setprop("sim/model/watercannon/tank-volume", hopperweight / 8.345);
    setprop("sim/model/watercannon/tank-weight", hopperweight);

    if (getprop("sim/model/watercannon/tank-volume") < 80) {
        setprop("sim/model/watercannon/tank-volume", 80);
    }
}

var digital_display =
  {

    new : func(designation, model_element, parameter, num_display, num_format, font_size, clr_r, clr_g, clr_b)
      {
        var obj = {parents : [digital_display] };
        obj.designation = designation;
        obj.model_element = model_element;
        obj.parameter = parameter;
        obj.num_format = num_format;

        var dev_canvas= canvas.new({
          "name": designation,
          "size": [128,128], 
          "view": [128,128],                        
          "mipmapping": 0     
        });

        dev_canvas.addPlacement({"node": model_element});
        dev_canvas.setColorBackground(0,0,0,0);

        obj._canvas = dev_canvas;

        var root = dev_canvas.createGroup();

        obj.string = root.createChild("text")
        .setText(num_display)
        .setColor(clr_r, clr_g, clr_b)
        .setFontSize(font_size)
        .setScale(1,3)
        .setFont("DSEG/DSEG7/Classic-MINI/DSEG7ClassicMini-Bold.ttf")
        .setAlignment("right-bottom")
        .setTranslation(110, 110);

        obj.string.enableUpdate();

        return obj;
      },

  display : func()
    {
      var string =  sprintf(me.num_format, getprop("sim/model/watercannon/"~me.parameter));
      me.string.updateText(string);
    },

  update: func()
    {
      me.display();
      settimer (func me.update(), 0.1);
    },
};

#var tank_volume_indicator = digital_display.new("Tank_Volume", "tank-volume-glass", "tank-volume", "0000", "%4.0f", "30", "1.0", "0.2", "0.2");
#tank_volume_indicator.update();
