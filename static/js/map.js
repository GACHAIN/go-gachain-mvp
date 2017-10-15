function gob(e) { if (typeof (e) == 'object') return (e); if (document.getElementById) return (document.getElementById(e)); return (eval(e)) }
var map;
var polyShape;
var markerShape;
var miniMapNum = 0;
//var oldDirMarkers = [];
//var tmpPolyLine;
var drawnShapes = [];
var holeShapes = [];
var startMarker;
var nemarker;
var tinyMarker;
var markers = [];
var midmarkers = [];
//var markerlistener1;
//var markerlistener2;
var rectangle;
var circle;
var southWest;
var northEast;
var centerPoint;
var radiusPoint;
var calc;
var startpoint;
var adder = 0;
var dirpointstart = null;
//var dirpointend = 0;
var dirline;
var waypts = [];
//var waypots = [];
var polyPoints = [];
var pointsArray = [];
var markersArray = [];
var addresssArray = [];
var pointsArrayKml = [];
var markersArrayKml = [];
var toolID = 1;
var codeID = 1;
var shapeId = 0;
var step = 0;
var plmcur = 0;
var lcur = 0;
var pcur = 0;
//var rcur = 0;
var ccur = 0;
var mcur = 0;
var outerPoints = [];
var holePolyArray = [];
var outerShape;
var anotherhole = false;
//var it;
var outerArray = [];
var innerArray = [];
var innerArrays = [];
var outerArrayKml = [];
var innerArrayKml = [];
var innerArraysKml = [];
var placemarks = [];
//var mylistener;
var editing = false;
var notext = false;
var textsignal = 0;
var kmlcode = ""; // Used as signal for have been logged
var javacode = ""; // Used as signal for have been logged
var polylineDecColorCur = "255,0,0";
var polygonDecColorCur = "255,0,0";
var docuname = "My document";
var docudesc = "Content";
var polylinestyles = [];
var polygonstyles = [];
//var rectanglestyles = [];
var circlestyles = [];
var markerstyles = [];
//var startLocation;
var endLocation;
//var dircount;
var dircountstart;
var firstdirclick = 0;
var dirmarknum = 1;
var directionsYes = 0;
var destinations = [];
var removedirectionleg = 0;
//var currentDirections = null;
//var oldpoint = null;
var prevpoint;
var prevnumber;
var directionsService = null;
var infoWindow = new BMap.InfoWindow('', {
    width: 150,
    height: 50
});
var tmpPolyLine = new BMap.Polyline([], {
    strokeColor: "#00FF00",
    strokeOpacity: 0.8,
    strokeWeight: 2
});
var tinyIcon = new BMap.Icon(
    'static/img/marker_red.png',
    new BMap.Size(12, 20),
    {}
);
/*var tinyShadow = new BMap.Icon(
    'icons/marker_20_shadow.png',
    new BMap.Size(22,20),
    {}
);*/
var imageNormal = new BMap.Icon(
    "images/square.png",
    new BMap.Size(11, 11),
    {}
);
var imageHover = new BMap.Icon(
    "images/square_over.png",
    new BMap.Size(11, 11),
    {}
);
var imageNormalMidpoint = new BMap.Icon(
    "images/square_transparent.png",
    new BMap.Size(11, 11),
    {}
);
/*var imageHoverMidpoint = new BMap.Icon(
	"square_transparent_over.png",
	new BMap.Size(11, 11),
	{}
);*/
function polystyle() {
    this.name = "Lump";
    this.kmlcolor = "CD0000FF";
    this.kmlfill = "9AFF0000";
    this.color = "#FF0000";
    this.fill = "#0000FF";
    this.width = 2;
    this.lineopac = 0.8;
    this.fillopac = 0.6;
}
function linestyle() {
    this.name = "Path";
    this.kmlcolor = "FF0000FF";
    this.color = "#FF0000";
    this.width = 3;
    this.lineopac = 1;
}
function circstyle() {
    this.name = "Circ";
    this.color = "#FF0000";
    this.fill = "#0000FF";
    this.width = 2;
    this.lineopac = 0.8;
    this.fillopac = 0.6;
}
function markerstyleobject() {
    this.name = "markerstyle";
    this.icon = "static/img/map/red-dot.png";
}
function placemarkobject() {
    this.name = "NAME";
    this.desc = "YES";
    this.style = "Path";
    this.stylecur = 0;
    this.tess = 1;
    this.alt = "clampToGround";
    this.plmtext = ""; // KLM text from <Placemark> to </Placemark>
    this.jstext = "";
    this.jscode = [];
    this.kmlcode = []; // coordinatepairs lng lat
    this.kmlholecode = []; // coordinatepairs lng lat
    this.poly = "pl";
    this.shape = null;
    this.point = null;
    this.toolID = 1;
    this.hole = 0;
    this.ID = 0;
}
function createplacemarkobject() {
    var thisplacemark = new placemarkobject();
    placemarks.push(thisplacemark);
}
function createpolygonstyleobject() {
    var polygonstyle = new polystyle();
    polygonstyles.push(polygonstyle);
}
function createlinestyleobject() {
    var polylinestyle = new linestyle();
    polylinestyles.push(polylinestyle);
}
function createcirclestyleobject() {
    var cirstyle = new circstyle();
    circlestyles.push(cirstyle);
}
function createmarkerstyleobject() {
    var thisstyle = new markerstyleobject();
    markerstyles.push(thisstyle);
}
function preparePolyline() {
    var polyOptions = {
        strokeColor: polylinestyles[lcur].color,
        strokeOpacity: polylinestyles[lcur].lineopac,
        strokeWeight: polylinestyles[lcur].width
    };
    polyShape = new BMap.Polyline(polyPoints, polyOptions);
    map.addOverlay(polyShape);
    /*var tmpPolyOptions = {
    	strokeColor: polylinestyles[lcur].color,
    	strokeOpacity: polylinestyles[lcur].lineopac,
    	strokeWeight: polylinestyles[lcur].width
    };
    tmpPolyLine = new BMap.Polyline([], tmpPolyOptions);
    map.addOverlay(tmpPolyLine);*/
}

function preparePolygon() {
    var polyOptions = {
        strokeColor: polygonstyles[pcur].color,
        strokeOpacity: polygonstyles[pcur].lineopac,
        strokeWeight: polygonstyles[pcur].width,
        fillColor: polygonstyles[pcur].fill,
        fillOpacity: polygonstyles[pcur].fillopac
    };
    polyShape = new BMap.Polygon(polyPoints, polyOptions);
    map.addOverlay(polyShape);
}
function activateRectangle() {
    rectangle = new BMap.Polygon([], {
        strokeColor: polygonstyles[pcur].color,
        strokeOpacity: polygonstyles[pcur].lineopac,
        strokeWeight: polygonstyles[pcur].width,
        fillColor: polygonstyles[pcur].fill,
        fillOpacity: polygonstyles[pcur].fillopac
    });
}
function activateCircle() {
    circle = new BMap.Circle(new BMap.Point(0, 0), 0, {
        fillColor: circlestyles[ccur].fill,
        fillOpacity: circlestyles[ccur].fillopac,
        strokeColor: circlestyles[ccur].color,
        strokeOpacity: circlestyles[ccur].lineopac,
        strokeWeight: circlestyles[ccur].width
    });
}
function activateMarker() {
    markerShape = new BMap.Marker(new BMap.Point(0, 0), {
        icon: markerstyles[mcur].icon
    });
}
function initmap() {
    var latlng = new BMap.Point(StateCenterY, StateCenterX);//(45.0,7.0);//45.074723, 7.656433
    var mapTypeIds = [
        BMAP_NORMAL_MAP,
        BMAP_PERSPECTIVE_MAP,
        BMAP_SATELLITE_MAP,
        BMAP_HYBRID_MAP
    ];
    copyrightNode = document.createElement('div');
    copyrightNode.id = 'copyright-control';
    copyrightNode.style.fontSize = '11px';
    copyrightNode.style.fontFamily = 'Arial, sans-serif';
    copyrightNode.style.margin = '0 2px 2px 0';
    copyrightNode.style.whiteSpace = 'nowrap';
    //copyrightNode.index = 0;
    var myOptions = {
        draggableCursor: 'default',
        draggingCursor: 'pointer',
        scaleControl: true,
        mapTypeControl: true,
        mapTypeControlOptions: { mapTypeIds: mapTypeIds },
        //mapTypeControlOptions:{style: BMAP_MAPTYPE_CONTROL_DROPDOWN},
        mapType: BMAP_NORMAL_MAP,
        styles: [{ featureType: 'poi', stylers: [{ visibility: 'off' }] }],
        streetViewControl: false
    };
    map = new BMap.Map('map_canvas', myOptions);
    map.enableScrollWheelZoom();
    map.centerAndZoom(latlng, StateZoom);
    map.addControl(new BMap.NavigationControl());
    map.addControl(new BMap.ScaleControl());
    map.addControl(new BMap.OverviewMapControl());
    map.addControl(new BMap.MapTypeControl());
    map.addControl(new BMap.GeolocationControl());
    map.addEventListener('maptypeid_changed', updateCopyrights);

    //var myStyle = [{featureType: 'poi', stylers: [{visibility: 'off'}]}];
    //map.setOptions({styles: myStyle}); // styles and stylers are arrays
    map.addOverlay(tmpPolyLine);
    createplacemarkobject();
    createlinestyleobject();
    createpolygonstyleobject();
    createcirclestyleobject();
    createmarkerstyleobject();
    preparePolyline(); // create a Polyline object

    map.addEventListener('click', addLatLng);
    map.addEventListener('zoom_changed', mapzoom);
    cursorposition(map);
}
// Called by initmap, addLatLng, drawRectangle, drawCircle, drawpolywithhole
function cursorposition(mapregion) {
    mapregion.addEventListener('mousemove', function (e) {
        var LnglatStr6 = e.point.lng.toFixed(6) + ', ' + e.point.lat.toFixed(6);
        var latLngStr6 = e.point.lat.toFixed(6) + ', ' + e.point.lng.toFixed(6);
        gob('over').options[0].text = LnglatStr6;
        gob('over').options[1].text = latLngStr6;
    });
}
function updateCopyrights() {
    if (map.getMapTypeId() == "OSM") {
        copyrightNode.innerHTML = "OSM map data @<a target=\"_blank\" href=\"http://www.openstreetmap.org/\"> OpenStreetMap</a>-contributors,<a target=\"_blank\" href=\"http://creativecommons.org/licenses/by-sa/2.0/legalcode\"> CC BY-SA</a>";
    } else {
        copyrightNode.innerHTML = "";
    }
}
function addLatLng(e) {
    if (directionsYes == 1) {
        drawDirections(e.point);
        return;
    }
    if (plmcur != placemarks.length - 1) {
        nextshape();
    }

    // Rectangle and circle can't collect points with getPath. solved by letting Polyline collect the points and then erase Polyline
    polyPoints = polyShape.getPath();
    polyPoints.push(e.point);
    // This codeline does the drawing on the map
    polyShape.setPath(polyPoints);
    if (polyPoints.length == 1) {
        startpoint = e.point;
        placemarks[plmcur].point = startpoint; // stored because it's to be used when the shape is clicked on as a stored shape
        setstartMarker(startpoint);
        if (toolID == 5) {
            drawMarkers(startpoint);
        }
    }
    if (polyPoints.length == 2 && toolID == 3) createrectangle(e.point);
    if (polyPoints.length == 2 && toolID == 4) createcircle(e.point);
    if (toolID == 1 || toolID == 2) { // if polyline or polygon
        var stringtobesaved = '"' + e.point.lat.toFixed(6) + '","' + e.point.lng.toFixed(6) + '"';
        var kmlstringtobesaved = '"' + e.point.lng.toFixed(6) + '","' + e.point.lat.toFixed(6) + '"';
        //Cursor position, when inside polyShape, is registered with this listener
        cursorposition(polyShape);
        if (adder == 0) { //shape with no hole
            pointsArray.push(stringtobesaved); // collect textstring for presentation in textarea
            pointsArrayKml.push(kmlstringtobesaved); // collect textstring for presentation in textarea
            if (polyPoints.length == 1 && toolID == 2) closethis('polygonstuff');
            if (codeID == 1 && toolID == 1) logCode1(); // write kml for polyline
            if (codeID == 1 && toolID == 2) logCode2(); // write kml for polygon
            if (codeID == 2) logCode4(); // write Google javascript
        }
        if (adder == 1) { // adder is increased in function holecreator
            outerArray.push(stringtobesaved);
            outerArrayKml.push(kmlstringtobesaved);
        }
        if (adder == 2) {
            innerArray.push(stringtobesaved);
            innerArrayKml.push(kmlstringtobesaved);
        }
    }
}
function setstartMarker(point) {
    startMarker = new BMap.Marker(point, {
        title: '#' + polyPoints.length
    });
    map.addOverlay(startMarker);
}
function createrectangle(e) {
    // startMarker is southwest point. now set northeast
    nemarker = new BMap.Marker(e.point, {
        draggable: true,
        raiseOnDrag: false,
        title: "Draggable"
    });
    startMarker.addEventListener('dragend', drawRectangle);
    nemarker.addEventListener('dragend', drawRectangle);
    startMarker.setDraggable(true);
    //startMarker.setAnimation(null);
    startMarker.setTitle("Draggable");
    startMarker.setOptions({ raiseOnDrag: false });
    map.removeOverlay(polyShape); // remove the Polyline that has collected the points
    map.addOverlay(nemarker);
    polyPoints = [];
    drawRectangle();
}
function setRectangleBounds(rectangle, bounds) {
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    rectangle.setPath([
        new BMap.Point(ne.lng, sw.lat),
        ne,
        new BMap.Point(sw.lng, ne.lat),
        sw
    ]);
}
function drawRectangle() {
    gob('EditButton').disabled = 'disabled';
    southWest = startMarker.getPosition(); // used in logCode6()
    northEast = nemarker.getPosition(); // used in logCode6()
    var latLngBounds = new BMap.Bounds(
        southWest,
        northEast
    );
    setRectangleBounds(rectangle, latLngBounds);
    //Cursor position, when inside rectangle, is registered with this listener
    cursorposition(rectangle);
    // the Rectangle was created in activateRectangle(), called from newstart(), which may have been called from setTool()
    var northWest = new BMap.Point(northEast.lng, southWest.lat);
    var southEast = new BMap.Point(southWest.lng, northEast.lat);
    polyPoints = [];
    pointsArray = [];
    pointsArrayKml = [];
    /*polyPoints.push(southWest);
    polyPoints.push(northWest);
    polyPoints.push(northEast);
    polyPoints.push(southEast);*/
    var stringtobesaved = '"' + southWest.lng.toFixed(6) + '","' + southWest.lat.toFixed(6) + '"';
    pointsArrayKml.push(stringtobesaved);
    stringtobesaved = '"' + southWest.lng.toFixed(6) + '","' + northEast.lat.toFixed(6) + '"';
    pointsArrayKml.push(stringtobesaved);
    stringtobesaved = '"' + northEast.lng.toFixed(6) + '","' + northEast.lat.toFixed(6) + '"';
    pointsArrayKml.push(stringtobesaved);
    stringtobesaved = '"' + northEast.lng.toFixed(6) + '","' + southWest.lat.toFixed(6) + '"';
    pointsArrayKml.push(stringtobesaved);
    stringtobesaved = '"' + southWest.lat.toFixed(6) + '","' + southWest.lng.toFixed(6) + '"';
    pointsArray.push(stringtobesaved);
    stringtobesaved = '"' + northEast.lat.toFixed(6) + '","' + southWest.lng.toFixed(6) + '"';
    pointsArray.push(stringtobesaved);
    stringtobesaved = '"' + northEast.lat.toFixed(6) + '","' + northEast.lng.toFixed(6) + '"';
    pointsArray.push(stringtobesaved);
    stringtobesaved = '"' + southWest.lat.toFixed(6) + '","' + northEast.lng.toFixed(6) + '"';
    pointsArray.push(stringtobesaved);
    southWest = northEast = null;
    if (codeID == 2) logCode6();
    if (codeID == 1) logCode2();
}
function createcircle(e) {
    // startMarker is center point. now set radius
    nemarker = new BMap.Marker(e.point, {
        draggable: true,
        raiseOnDrag: false,
        title: "Draggable"
    });
    startMarker.addEventListener('drag', drawCircle);
    nemarker.addEventListener('drag', drawCircle);
    startMarker.setDraggable(true);
    startMarker.setAnimation(null);
    startMarker.setTitle("Draggable");
    drawCircle();
    map.removeOverlay(polyShape); // remove the Polyline that has collected the points
    polyPoints = [];
}
function drawCircle() {
    centerPoint = startMarker.getPosition();
    radiusPoint = nemarker.getPosition();
    circle.bindTo('center', startMarker, 'position');
    calc = distance(centerPoint.lat, centerPoint.lng, radiusPoint.lat, radiusPoint.lng);
    circle.setRadius(calc);
    //Cursor position, when inside circle, is registered with this listener
    cursorposition(circle);
    codeID = gob('codechoice').value = 2;
    logCode7();
}
// calculate distance between two coordinates
function distance(lat1, lon1, lat2, lon2) {
    var R = 6371000; // earth's radius in meters
    var dLat = (lat2 - lat1) * Math.PI / 180;
    var dLon = (lon2 - lon1) * Math.PI / 180;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    var d = R * c;
    return d;
}

function drawMarkers(point) {
    if (startMarker) map.removeOverlay(startMarker);
    if (polyShape) map.removeOverlay(polyShape);
    var id = plmcur;
    placemarks[plmcur].jscode = point.lat.toFixed(6) + ',' + point.lng.toFixed(6);
    placemarks[plmcur].kmlcode = point.lng.toFixed(6) + ',' + point.lat.toFixed(6);
    activateMarker();
    markerShape.setPosition(point);
    var marker = markerShape;
    tinyMarker = new BMap.Marker(placemarks[plmcur].point, {
        icon: tinyIcon
    });
    marker.addEventListener('click', function (event) {
        plmcur = id;
        markerShape = marker;
        var html = "<b>" + placemarks[plmcur].name + "</b> <br/>" + placemarks[plmcur].desc;
        infoWindow.setContent(html);
        if (tinyMarker) map.removeOverlay(tinyMarker);
        tinyMarker = new BMap.Marker(placemarks[plmcur].point, {
            icon: tinyIcon
        });
        if (toolID != 5) toolID = gob('toolchoice').value = 5;
        if (codeID == 1) logCode9();
        if (codeID == 2) logCode8();
        map.openInfoWindow(infoWindow, point);
    });
    drawnShapes.push(markerShape);
    if (codeID == 2) logCode8();
    if (codeID == 1) logCode9();
}
function drawDirections(point) {
    if (firstdirclick > 2) {
        //if(oldpoint) waypts.push({location:oldpoint, stopover:true});
        var request = {
            origin: dirpointstart,
            destination: point,
            waypoints: waypts,
            travelMode: BMAP_ROUTE_TYPE_DRIVING
        };
        //oldpoint = point;
        waypts.push({ location: point, stopover: true });
        destinations.push(request.destination);
        calcRoute(request);
    }
    if (firstdirclick == 2) {
        request = {
            origin: dirpointstart,
            destination: point,
            travelMode: BMAP_ROUTE_TYPE_DRIVING
        };
        //oldpoint = point;
        waypts.push({ location: point, stopover: true });
        destinations.push(request.destination);
        calcRoute(request);
    }
    if (dirpointstart == null) {
        dirpointstart = point;
        firstdirclick = 1;
        //increaseplmcur(); // not necessary?
        dirline = plmcur;
        placemarks[dirline].shape = polyShape; // created in preparePolyline(), initiated in newstart() called from setTool()
        placemarks[dirline].point = dirpointstart;
        request = {
            origin: dirpointstart,
            destination: point,
            travelMode: BMAP_ROUTE_TYPE_DRIVING
        };
        //destinations.push(request.destination);
        calcRoute(request);

        //dirpointend = 1;
        dircountstart = dirline + 1;
    }
}
//}
function calcRoute(request) {
    firstdirclick++;
    if (directionsService === null) {
        directionsService = new BMap.DrivingRoute(map, {
            onSearchComplete: function(result) { console.log(result); },
            renderOptions: {
                map: map
            }
        });
    }
    directionsService.search(request.origin, request.destination, {});
}
function RenderCustomDirections(response) {
    if (getNumPlans() > 0) {
        //var m = step + 1;
        //if(removedirectionleg == 1) m = m - 1;
        var result = response.routes[0];
        var legs = response.routes[0].legs;
        polyPoints = [];
        pointsArray = [];
        pointsArrayKml = [];
        /*if(firstdirclick > 2) {
            result.overview_path.shift();
        }*/
        for (var i = 0; i < result.overview_path.length; i++) {
            polyPoints.push(result.overview_path[i]);
            pointsArray.push(result.overview_path[i].lat.toFixed(6) + ',' + result.overview_path[i].lng.toFixed(6));
            pointsArrayKml.push(result.overview_path[i].lng.toFixed(6) + ',' + result.overview_path[i].lat.toFixed(6));
        }
        polyShape.setPath(polyPoints);
        endLocation = new Object();
        if (step == 0) {
            createdirMarker(legs[step].start_location, legs[step].start_address);
            markersArray.push(legs[step].start_location.lat.toFixed(6) + ',' + legs[step].start_location.lng.toFixed(6));
            markersArrayKml.push(legs[step].start_location.lng.toFixed(6) + ',' + legs[step].start_location.lat.toFixed(6));
            addresssArray.push(legs[step].start_address);
            //placemarks[plmcur].name = "Marker "+dirmarknum;
        }
        if (step > 0 && removedirectionleg == 0) {
            endLocation.point = legs[step - 1].end_location;
            endLocation.address = legs[step - 1].end_address;
            createdirMarker(endLocation.point, endLocation.address);
            markersArray.push(endLocation.point.lat.toFixed(6) + ',' + endLocation.point.lng.toFixed(6));
            markersArrayKml.push(endLocation.point.lng.toFixed(6) + ',' + endLocation.point.lat.toFixed(6));
            addresssArray.push(endLocation.address);
            //placemarks[plmcur].name = "Marker "+dirmarknum;
        }
        removedirectionleg = 0;
        //logCode1a();
        //dirmarknum++;
        step++;
        //placemarks[plmcur].desc = addresssArray[addresssArray.length-1];
        docudetails();
        //showthis('toppers');
    }
    else alert('No directions found');
}
function createdirMarker(latlng, html) {
    if (tinyMarker) map.removeOverlay(tinyMarker);
    createplacemarkobject();
    plmcur++; // plmcur = placemarks.length -1;
    activateMarker();
    placemarks[plmcur].name = "Marker " + dirmarknum;
    markerShape.setTitle(placemarks[plmcur].name + "\n" + html);
    markerShape.setPosition(latlng);
    placemarks[plmcur].jscode = latlng.lat.toFixed(6) + ',' + latlng.lng.toFixed(6);
    placemarks[plmcur].kmlcode = latlng.lng.toFixed(6) + ',' + latlng.lat.toFixed(6);
    placemarks[plmcur].desc = html;
    placemarks[plmcur].point = latlng;
    placemarks[plmcur].style = markerstyles[mcur].name;
    placemarks[plmcur].stylecur = mcur;
    placemarks[plmcur].shape = markerShape;
    drawnShapes.push(markerShape);
    dirmarknum++;
    var marker = markerShape;
    var thisshape = plmcur;
    marker.addEventListener('click', function (event) {
        markerShape = marker;
        plmcur = thisshape;
        //var htm = "<b>" + placemarks[thisshape].name + "</b> <br/>" + placemarks[thisshape].desc;
        if (polyPoints == 0) {
            //infoWindow.setContent(htm);
            if (tinyMarker) map.removeOverlay(tinyMarker);
            tinyMarker = new BMap.Marker(placemarks[plmcur].point, {
                icon: tinyIcon
            });
            if (toolID != 5) {
                toolID = gob('toolchoice').value = 5;
                directionsYes = 0;
            }
            if (codeID == 1) logCode9();
            if (codeID == 2) logCode8();
            //map.openInfoWindow(infoWindow, latlng);
        }
    });
    drawnShapes.push(markerShape);
}
// Called from deleteLastPoint() initiated by click on button
function undo() {
    if (drawnShapes.length > 1) {
        map.removeOverlay(drawnShapes[drawnShapes.length - 1]);
        destinations.pop();
        var point = destinations[destinations.length - 1];
        waypts.pop();
        var request = {
            origin: dirpointstart,
            destination: point,
            waypoints: waypts,
            travelMode: BMAP_ROUTE_TYPE_DRIVING
        };
        placemarks.pop();
        markersArray.pop();
        markersArrayKml.pop();
        addresssArray.pop();
        firstdirclick = firstdirclick - 1;
        step = step - 1;
        dirmarknum = dirmarknum - 1;
        plmcur = plmcur - 1;
        removedirectionleg = 1;
        calcRoute(request);
    }
}

// Not used
function setDirectionsMarker(point) {
    var image = new BMap.Icon('static/img/map/square.png',
        new BMap.Size(12, 12),
        {});
    var marker = new BMap.Marker(point, {
        icon: image
    });
    var shadow = new BMap.Icon('static/img/map/msmarker.shadow.png',
        new BMap.Size(37, 32),
        {});
    var title = "#" + markers.length;
    var id = plmcur;
    placemarks[plmcur].point = point;
    placemarks[plmcur].coord = point.lng.toFixed(6) + ', ' + point.lat.toFixed(6);
    /*var marker = new BMap.Marker(point, {
        draggable: true,
        icon: image,
        shadow: shadow});*/
    //marker.setTitle(title);
    //markers.push(marker);
}

function setTool() {
    if (polyPoints.length == 0 && kmlcode == "" && javacode == "") {
        newstart();
    } else {
        if (toolID == 1) { // polyline
            // change to polyline draw mode not allowed
            /*if(outerArray.length > 0) { //indicates polygon with hole
                toolID = 2;
                nextshape();
                toolID = 1;
                newstart();
                return;
            }
            if(rectangle) {
                toolID = 3;
                nextshape();
                toolID = 1;
                newstart();
                return;
            }
            if(circle) {
                toolID = 4;
                nextshape();
                toolID = 1;
                newstart();
                return;
            }
            if(markerShape) {
                toolID = 5;
                nextshape();
                toolID = 1;
                newstart();
                return;
            }
            if(directionsYes == 1) {
                toolID = 6;
                nextshape();
                directionsYes = 0;
                toolID = 1;
                newstart();
                return;
            }*/
            placemarks[plmcur].style = polylinestyles[polylinestyles.length - 1].name;
            placemarks[plmcur].stylecur = polylinestyles.length - 1;
            if (polyShape) map.removeOverlay(polyShape);
            preparePolyline(); //if a polygon exists, it will be redrawn as polylines
            if (codeID == 1) logCode1(); // KML
            if (codeID == 2) logCode4(); // Javascipt
        }
        if (toolID == 2) { // polygon
            //alert(toolID + " " + codeID);
            /*if(rectangle) {
                toolID = 3;
                nextshape();
                toolID = 2;
                newstart();
                return;
            }
            if(circle) {
                //alert(toolID + " " + codeID);
                toolID = 4;
                nextshape();
                toolID = 2;
                newstart();
                return;
            }
            if(markerShape) {
                toolID = 5;
                nextshape();
                toolID = 2;
                newstart();
                return;
            }
            if(directionsYes == 1) {
                toolID = 6;
                nextshape();
                directionsYes = 0;
                toolID = 2;
                newstart();
                return;
            }*/
            placemarks[plmcur].style = polygonstyles[polygonstyles.length - 1].name;
            placemarks[plmcur].stylecur = polygonstyles.length - 1;
            if (polyShape) map.removeOverlay(polyShape);
            preparePolygon(); //if a polyline exists, it will be redrawn as a polygon
            if (codeID == 1) logCode2(); // KML
            if (codeID == 2) logCode4(); // Javascript
        }
        if (toolID == 3 || toolID == 4 || toolID == 5 || toolID == 6) {
            if (polyShape) map.removeOverlay(polyShape);
            if (circle) map.removeOverlay(circle);
            if (rectangle) map.removeOverlay(rectangle);
            directionsYes = 0;
            newstart();
        }
        //alert(toolID + " " + codeID);
    }
}
function setCode() {
    if (toolID == 4) { // circle
        codeID = gob('codechoice').value = 2; // javascript
        return;
    }
    if (toolID == 6) { // directions
        codeID = gob('codechoice').value = 1; // KML
        return;
    }
    if (polyPoints.length !== 0 || kmlcode !== "" || javacode !== "") {
        if (codeID == 1 && toolID == 1) logCode1();
        if (codeID == 1 && toolID == 2 && outerArray.length == 0) logCode2();
        if (codeID == 1 && toolID == 2 && outerArray.length > 0) logCode3();
        if (codeID == 2 && toolID == 1) logCode4(); // write Google javascript
        if (codeID == 2 && toolID == 2 && outerArray.length == 0) logCode4();
        if (codeID == 2 && toolID == 2 && outerArray.length > 0) logCode5();
        if (toolID == 3) { // rectangle
            if (codeID == 1) logCode2();
            if (codeID == 2) logCode6();
        }
        if (toolID == 5) { // marker
            if (codeID == 1) logCode9();
            if (codeID == 2) logCode8();
        }
    }
}
function increaseplmcur() {
    if (placemarks[plmcur].plmtext != "") {
        if (toolID == 1 || toolID == 2 && directionsYes == 0) {
            placemarks[plmcur].shape = polyShape;
            addpolyShapelistener();
            createplacemarkobject();
            plmcur = placemarks.length - 1;
        }
        if (markerShape && directionsYes == 0) {
            placemarks[plmcur].shape = markerShape;
            createplacemarkobject();
            plmcur = placemarks.length - 1;
        }
        if (toolID == 3 && directionsYes == 0) {
            placemarks[plmcur].shape = rectangle;
            addpolyShapelistener();
            createplacemarkobject();
            plmcur = placemarks.length - 1;
        }
        //Set a listener on the directions line (path)
        if (directionsYes == 1) {
            placemarks[plmcur].shape = polyShape;
            plmcur = dirline;
            addpolyShapelistener();
            createplacemarkobject();
            plmcur = placemarks.length - 1;
        }
    }
}
//Saving of data for current shape on the map will be completed and a listener set on it
//Then all variables will be nulled in newstart
function nextshape() {
    gob('EditButton').disabled = '';
    if (editing == true) stopediting();
    //If a saved shape has been inspected, set a new listener on it
    if (plmcur < placemarks.length - 1) {
        addpolyShapelistener();
        plmcur = placemarks.length - 1;
    }
    //Set listener on current shape. Create new placemark object.
    //Increase counter for placemark
    increaseplmcur();
    if (polyShape) drawnShapes.push(polyShape); // used in clearMap, to have it removed from the map, map.removeOverlay(drawnShapes[i]);
    if (outerShape) drawnShapes.push(outerShape);
    if (circle) drawnShapes.push(circle);
    if (rectangle) drawnShapes.push(rectangle);
    if (tinyMarker) drawnShapes.push(tinyMarker);
    // markerShape has been pushed in drawMarkers and createdirMarker
    polyShape = null;
    outerShape = null;
    rectangle = null;
    circle = null;
    markerShape = null;
    newstart();
}
function addpolyShapelistener() {
    var thisshape = plmcur;
    // In v2 I can give a shape an ID and have that ID revealed, with the map listener, when the shape is clicked on
    // I can't do that in v3. Instead I put a listener on the shape
    if (toolID == 1 || toolID == 2) {
        polyShape.addEventListener('click', function (point) {
            if (tinyMarker) map.removeOverlay(tinyMarker);
            if (startMarker) map.removeOverlay(startMarker);
            directionsYes = 0;
            polyShape = placemarks[thisshape].shape;
            plmcur = thisshape;
            polyPoints = polyShape.getPath();
            if (placemarks[plmcur].poly == "pl") {
                pointsArray = placemarks[plmcur].jscode;
                pointsArrayKml = placemarks[plmcur].kmlcode;
                toolID = gob('toolchoice').value = 1;
                lcur = placemarks[plmcur].stylecur;
                if (codeID == 1) logCode1();
                if (codeID == 2) logCode4(); // write Google javascript
            }
            if (placemarks[plmcur].poly == "pg") {
                pointsArray = placemarks[plmcur].jscode;
                pointsArrayKml = placemarks[plmcur].kmlcode;
                toolID = gob('toolchoice').value = 2;
                pcur = placemarks[plmcur].stylecur;
                if (codeID == 1) logCode2();
                if (codeID == 2) logCode4(); // write Google javascript
            }
            if (placemarks[plmcur].poly == "pgh") {
                outerArrayKml = placemarks[plmcur].kmlcode;
                innerArraysKml = placemarks[plmcur].kmlholecode;
                /*var polly = polyShape.getPaths();
                polyPoints = polly[0];
                var points = polly[0];
                //alert(point.lng.toFixed(6));
                for(var i = 0; i<points.length-1; i++) {
                    outerArray.push(points[i].lat.toFixed(6) + ',' + points[i].lng.toFixed(6));
                    outerArrayKml.push(points[i].lng.toFixed(6) + ',' + points[i].lat.toFixed(6));
                }
                for(i = 1; i<polly.length; i++) {
                    points = polly[i];
                    if(i == polly.length-1) {
                        for(var j = 0; j<points.length; j++) {
                            innerArray.push(points[j].lat.toFixed(6) + ',' + points[j].lng.toFixed(6));
                            innerArrayKml.push(points[j].lng.toFixed(6) + ',' + points[j].lat.toFixed(6));
                        }
                    }else{
                        for(var j = 0; j<points.length-1; j++) {
                            innerArray.push(points[j].lat.toFixed(6) + ',' + points[j].lng.toFixed(6));
                            innerArrayKml.push(points[j].lng.toFixed(6) + ',' + points[j].lat.toFixed(6));
                        }
                    }
                    innerArrays.push(innerArray);
                    innerArraysKml.push(innerArrayKml);
                    innerArray = [];
                    innerArrayKml = [];
                }*/
                toolID = gob('toolchoice').value = 2;
                pcur = placemarks[plmcur].stylecur;
                if (codeID == 1) logCode3();
                if (codeID == 2) logCode5(); // write Google javascript
            }
            tinyMarker = new BMap.Marker(placemarks[plmcur].point, {
                icon: tinyIcon
            });
            closethis('polygonstuff');
        });
    }
    if (toolID == 3) {
        rectangle.addEventListener('click', function (point) {
            gob('EditButton').disabled = 'disabled';
            if (tinyMarker) map.removeOverlay(tinyMarker);
            if (startMarker) map.removeOverlay(startMarker);
            if (nemarker) map.removeOverlay(nemarker);
            directionsYes = 0;
            rectangle = placemarks[thisshape].shape;
            plmcur = thisshape;
            pointsArray = placemarks[plmcur].jscode;
            pointsArrayKml = placemarks[plmcur].kmlcode;
            toolID = gob('toolchoice').value = 3;
            pcur = placemarks[plmcur].stylecur;
            var latlongs = rectangle.getBounds();
            var southwest = latlongs.getSouthWest();
            var northeast = latlongs.getNorthEast();
            startMarker = new BMap.Marker(southwest, {
                draggable: true,
                raiseOnDrag: false,
                title: "Draggable"
            });
            map.addOverlay(startMarker);
            nemarker = new BMap.Marker(northeast, {
                draggable: true,
                raiseOnDrag: false,
                title: "Draggable"
            });
            map.addOverlay(nemarker);
            startMarker.addEventListener('dragend', drawRectangle);
            nemarker.addEventListener('dragend', drawRectangle);
            if (codeID == 1) logCode2();
            if (codeID == 2) logCode6(); // write Google javascript
            closethis('polygonstuff');
        });
    }
}
// Clear current Map
function clearMap(full) {
    if (editing == true) stopediting();
    if (polyShape) map.removeOverlay(polyShape); // polyline or polygon
    if (outerShape) map.removeOverlay(outerShape);
    if (rectangle) map.removeOverlay(rectangle);
    if (circle) map.removeOverlay(circle);
    if (drawnShapes.length > 0) {
        for (var i = 0; i < drawnShapes.length; i++) {
            map.removeOverlay(drawnShapes[i]);
        }
    }
    plmcur = 0;
    dirmarknum = 1;
    newstart(full);
    placemarks = [];
    createplacemarkobject();
    gob('eGaaSCoords').value = '';
}
function newstart(full) {
    if (!full && StateCoords) {
        polyPoints = [];
        pointsArray = [];
        gob('eGaaSCoords').value = '';
        polyPoints = StateCoords;
        for (var i = 0; i < StateCoords.length; i++) {
            var point = '"' + StateCoords[i].lat + '","' + StateCoords[i].lng + '"';
            pointsArray.push(point);
        }
    } else {
        polyPoints = [];
        pointsArray = [];
    }
    outerPoints = [];
    markersArray = [];
    pointsArrayKml = [];
    markersArrayKml = [];
    addresssArray = [];
    outerArray = [];
    innerArray = [];
    outerArrayKml = [];
    innerArrayKml = [];
    holePolyArray = [];
    innerArrays = [];
    innerArraysKml = [];
    waypts = [];
    destinations = [];
    adder = 0;
    dirpointstart = null;
    dirline = null;
    firstdirclick = 0;
    //dirmarknum = 1;
    step = 0;
    if (directionsYes == 1 && toolID != 6) directionsYes = 0;
    closethis('polylineoptions');
    closethis('polygonoptions');
    closethis('circleoptions');
    if (toolID != 2) closethis('polygonstuff');
    if (startMarker) map.removeOverlay(startMarker);
    if (nemarker) map.removeOverlay(nemarker);
    if (tinyMarker) map.removeOverlay(tinyMarker);
    if (toolID == 1) {
        placemarks[plmcur].style = polylinestyles[polylinestyles.length - 1].name;
        placemarks[plmcur].stylecur = polylinestyles.length - 1;
        preparePolyline();
        polylineintroduction();
    }
    if (toolID == 2) {
        showthis('polygonstuff');
        //gob('stepdiv').innerHTML = "Step 0";
        placemarks[plmcur].style = polygonstyles[polygonstyles.length - 1].name;
        placemarks[plmcur].stylecur = polygonstyles.length - 1;
        preparePolygon();
        polygonintroduction();
    }
    if (toolID == 3) {
        placemarks[plmcur].style = polygonstyles[polygonstyles.length - 1].name;
        placemarks[plmcur].stylecur = polygonstyles.length - 1;
        preparePolyline(); // use Polyline to collect clicked point
        activateRectangle();
        rectangleintroduction();
    }
    if (toolID == 4) {
        placemarks[plmcur].style = circlestyles[circlestyles.length - 1].name;
        placemarks[plmcur].stylecur = circlestyles.length - 1;
        preparePolyline(); // use Polyline to collect clicked point
        activateCircle();
        circleintroduction();
        codeID = gob('codechoice').value = 2; // javascript, no KML for circle
    }
    if (toolID == 5) {
        placemarks[plmcur].style = markerstyles[markerstyles.length - 1].name;
        placemarks[plmcur].stylecur = markerstyles.length - 1;
        preparePolyline();
        markerintroduction();
    }
    if (toolID == 6) {
        directionsYes = 1;
        /*if(dirline != null) {
            placemarks[plmcur].style = placemarks[dirline].style;
            placemarks[plmcur].stylecur = placemarks[dirline].stylecur;
        }else{*/
        placemarks[plmcur].style = polylinestyles[polylinestyles.length - 1].name;
        placemarks[plmcur].stylecur = polylinestyles.length - 1;
        //}
        preparePolyline();
        directionsintroduction();
        codeID = gob('codechoice').value = 1;
    }
    kmlcode = "";
    javacode = "";
    //alert(toolID + " " + codeID);
}

function deleteLastPoint() {
    if (polyPoints.length < 2) return;
    if (directionsYes == 1) {
        if (destinations.length == 1) return;
        undo();
        return;
    }
    if (toolID == 1) {
        if (polyShape) {
            polyPoints = polyShape.getPath();
            if (polyPoints.length > 0) {
                polyPoints.splice(polyPoints.length - 1, 1);
                polyShape.setPath(polyPoints);
                pointsArrayKml.pop();
                pointsArray.pop();
                if (codeID == 1) logCode1();
                if (codeID == 2) logCode4();
            }
        }
    }
    if (toolID == 2) {
        if (innerArrayKml.length > 0) {
            innerArrayKml.pop();
            innerArray.pop();
            polyPoints.splice(polyPoints.length - 1, 1);
        }
        if (outerArrayKml.length > 0 && innerArrayKml.length == 0) {
            outerArrayKml.pop();
            outerArray.pop();
            //polyPoints.splice(polyPoints.length - 1, 1);
        }
        if (outerPoints.length === 0) {
            if (polyShape) {
                polyPoints = polyShape.getPath();
                if (polyPoints.length > 0) {
                    polyPoints.splice(polyPoints.length - 1, 1);
                    polyShape.setPath(polyPoints);
                    pointsArrayKml.pop();
                    pointsArray.pop();
                    if (adder == 0) {
                        if (codeID == 1) logCode2();
                        if (codeID == 2) logCode4();
                    }
                }
            }
        }
    }
    if (polyPoints.length === 0) nextshape();
}
function counter(num) {
    return adder = adder + num;
}
// Called from link 'Hole' in div 'polygonstuff'
function holecreator() {
    var holestep = counter(1); // adder is increased here
    if (holestep == 1) {
        if (gob('stepdiv').innerHTML == "Finished") {
            adder = 0;
            return;
        } else {
            if (startMarker) map.removeOverlay(startMarker);
            if (polyShape) map.removeOverlay(polyShape);
            polyPoints = [];
            preparePolyline();
            //gob('stepdiv').innerHTML = "Step 1";
            /*gob('eGaaSCoords').value = 'You may now draw the outer boundary. When finished, click Hole to move on to the next step.'
            +' Remember, you do not have to let start and end meet.'
            +' The API will close the shape in the finished polygon.';*/
        }
    }
    if (holestep == 2) {
        // innerArray and innerArrayKml will be collected in function addLatLng
        if (anotherhole == false) {
            // outer line is finished, in Polyline draw mode
            polyPoints.push(startpoint); // let start and end for outer line meet
            outerPoints = polyPoints; // store polyPoints in outerPoints. polyPoints will be reused for inner lines
            holePolyArray.push(outerPoints); // this will be the points array for polygon with hole when the points for inner lines are added
            outerShape = polyShape; // store polyShape in outerShape. polyShape will be reused for inner lines
        }
        /*gob('stepdiv').innerHTML = "Step 2";
        gob('eGaaSCoords').value = 'You may now draw an inner boundary. Click Hole again to see the finished polygon. '+
        'You may draw more than one hole: Click Next hole and draw before you click Hole.';*/
        if (anotherhole == true) { // set to true in nexthole
            // a hole has been drawn, another is about to be drawn
            if (polyShape && polyPoints.length == 0) {
                map.removeOverlay(polyShape);
                /*gob('eGaaSCoords').value = 'Oops! Not programmed yet, but you may continue drawing holes. '+
                'Everything you have created will show up when you click Hole again.';*/
            } else {
                polyPoints.push(startpoint);
                holePolyArray.push(polyPoints);
                if (innerArray.length > 0) innerArrays.push(innerArray);
                if (innerArrayKml.length > 0) innerArraysKml.push(innerArrayKml);
                holeShapes.push(polyShape);
                innerArray = [];
                innerArrayKml = [];
            }
        }
        polyPoints = [];
        preparePolyline();
        if (startMarker) map.removeOverlay(startMarker);
    }
    if (holestep == 3) {
        if (startMarker) map.removeOverlay(startMarker);
        if (outerShape) map.removeOverlay(outerShape);
        if (polyShape) map.removeOverlay(polyShape);
        if (polyPoints.length > 0) holePolyArray.push(polyPoints);
        if (innerArray.length > 0) innerArrays.push(innerArray);
        if (innerArrayKml.length > 0) innerArraysKml.push(innerArrayKml);
        drawpolywithhole();
        gob('stepdiv').innerHTML = "Finished";
        adder = 0;
        if (codeID == 1) logCode3();
        if (codeID == 2) logCode5();
    }
}
function drawpolywithhole() {
    if (holeShapes.length > 0) {
        for (var i = 0; i < holeShapes.length; i++) {
            map.removeOverlay(holeShapes[i]);
        }
    }
    var polyOptions = {
        strokeColor: polygonstyles[pcur].color,
        strokeOpacity: polygonstyles[pcur].lineopac,
        strokeWeight: polygonstyles[pcur].width,
        fillColor: polygonstyles[pcur].fill,
        fillOpacity: polygonstyles[pcur].fillopac
    };
    polyShape = new BMap.Polygon(holePolyArray, polyOptions);
    map.addOverlay(polyShape);
    //Cursor position, when inside polyShape, is registered with this listener
    cursorposition(polyShape);
    anotherhole = false;
    if (startMarker) map.removeOverlay(startMarker);;
    startMarker = new BMap.Marker(outerPoints[0], {});
    startMarker.setTitle("Polygon with hole");
    map.addOverlay(startMarker);
    placemarks[plmcur].point = outerPoints[0];
}
// Called from button 'Next hole' in div 'polygonstuff'
function nexthole() {
    if (gob('stepdiv').innerHTML != "Finished") {
        if (outerPoints.length > 0) {
            adder = 1;
            anotherhole = true;
            drawnShapes.push(polyShape);
            holecreator();
        }
    }
}
function stopediting() {
    editing = false;
    gob('EditButton').value = 'Edit lines';
    closethis('RegretButton');
    if (outerArray.length > 0) {
        polyShape.setEditable(false);
        outerArray = [];
        outerArrayKml = [];
        innerArray = [];
        innerArrays = [];
        innerArrayKml = [];
        innerArraysKml = [];
        var polly = polyShape.getPaths();
        polyPoints = polly[0];
        var points = polly[0];
        //alert(point.lng.toFixed(6));
        for (var i = 0; i < points.length - 1; i++) {
            outerArray.push(point[i].lat.toFixed(6) + ',' + points[i].lng.toFixed(6));
            outerArrayKml.push(points[i].lng.toFixed(6) + ',' + points[i].lat.toFixed(6));
        }
        for (i = 1; i < polly.length; i++) {
            points = polly[i];
            if (i == polly.length - 1) {
                for (var j = 0; j < points.length; j++) {
                    innerArray.push(points[j].lat.toFixed(6) + ',' + points[j].lng.toFixed(6));
                    innerArrayKml.push(points[j].lng.toFixed(6) + ',' + points[j].lat.toFixed(6));
                }
            } else {
                for (var j = 0; j < points.length - 1; j++) {
                    innerArray.push(points[j].lat.toFixed(6) + ',' + points[j].lng.toFixed(6));
                    innerArrayKml.push(points[j].lng.toFixed(6) + ',' + points[j].lat.toFixed(6));
                }
            }
            innerArrays.push(innerArray);
            innerArraysKml.push(innerArrayKml);
            innerArray = [];
            innerArrayKml = [];
        }
        toolID = gob('toolchoice').value = 2;
        //closethis('polygonstuff');
        pcur = placemarks[plmcur].stylecur;
        if (codeID == 1) logCode3();
        if (codeID == 2) logCode5(); // write Google javascript
    } else {
        for (var i = 0; i < markers.length; i++) {
            map.removeOverlay(markers[i]);
        }
        for (var i = 0; i < midmarkers.length; i++) {
            map.removeOverlay(midmarkers[i]);
        }
        polyPoints = polyShape.getPath();
        markers = [];
        midmarkers = [];
        if (plmcur != placemarks.length - 1) {
            placemarks[plmcur].shape = polyShape;
            drawnShapes.push(polyShape);
            addpolyShapelistener();
        }
        //setstartMarker(polyPoints[0]);
    }
}
// the "Edit lines" button has been pressed
function editlines() {
    if (editing == true) {
        stopediting();
    } else {
        if (outerArray.length > 0) {
            polyShape.setEditable(true);
            closethis('polygonstuff');
        } else {
            //polyPoints = polyShape.getPath();
            if (polyPoints.length > 0) {
                showthis('RegretButton');
                toolID = gob('toolchoice').value = 1; // editing is set to be possible only in polyline draw mode
                setTool();
                if (startMarker) map.removeOverlay(startMarker);
                /*polyShape.setOptions({
                    editable: true
                });*/
                for (var i = 0; i < polyPoints.length; i++) {
                    var marker = setmarkers(polyPoints[i]);
                    markers.push(marker);
                    if (i > 0) {
                        var previous = polyPoints[i - 1];
                        var midmarker = setmidmarkers(polyPoints[i], previous);
                        midmarkers.push(midmarker);
                    }
                }
            }
        }
        editing = true;
        gob('EditButton').value = 'Stop edit';
    }
}
function regret() {
    if (polyPoints.length == 0) return;
    for (var i = 0; i < markers.length; i++) {
        map.removeOverlay(markers[i]);
    }
    for (var i = 0; i < midmarkers.length; i++) {
        map.removeOverlay(midmarkers[i]);
    }
    polyPoints.splice(prevnumber, 0, prevpoint);
    polyShape.setPath(polyPoints);
    //editing = false;
    stopediting();
    editlines();
}
// Called from editlines and listener set in setmidmarkers
function setmarkers(point) {
    var marker = new BMap.Marker(point, {
        icon: imageNormal,
        raiseOnDrag: false,
        draggable: true
    });
    marker.addEventListener("mouseover", function () {
        marker.setIcon(imageHover);
    });
    marker.addEventListener("mouseout", function () {
        marker.setIcon(imageNormal);
    });
    marker.addEventListener("drag", function () {
        for (var i = 0; i < markers.length; i++) {
            if (markers[i] == marker) {
                prevpoint = marker.getPosition();
                prevnumber = i;
                polyShape.getPath().setAt(i, marker.getPosition());
                movemidmarker(i);
                break;
            }
        }
        polyPoints = polyShape.getPath();
        var stringtobesaved = '"' + marker.getPosition().lat.toFixed(6) + '","' + marker.getPosition().lng.toFixed(6) + '"';
        var kmlstringtobesaved = '"' + marker.getPosition().lng.toFixed(6) + '","' + marker.getPosition().lat.toFixed(6) + '"';
        pointsArray.splice(i, 1, stringtobesaved);
        pointsArrayKml.splice(i, 1, kmlstringtobesaved);
        logCode1();
    });
    marker.addEventListener("click", function () {
        for (var i = 0; i < markers.length; i++) {
            if (markers[i] == marker && markers.length != 1) {
                prevpoint = marker.getPosition();
                prevnumber = i;
                map.removeOverlay(marker);
                markers.splice(i, 1);
                polyShape.getPath().splice(i, 1);
                removemidmarker(i);
                break;
            }
        }
        polyPoints = polyShape.getPath();
        if (markers.length > 0) {
            pointsArray.splice(i, 1);
            pointsArrayKml.splice(i, 1);
            logCode1();
        }
    });
    return marker;
}
// Called from editlines and listener set in this function
function setmidmarkers(point, prevpoint) {
    //var prevpoint = markers[markers.length-2].getPosition();
    var position = new BMap.Point(
        point.lng - (0.5 * (point.lng - prevpoint.lng)),
        point.lat - (0.5 * (point.lat - prevpoint.lat))
    );
    var marker = new BMap.Marker(position, {
        icon: imageNormalMidpoint,
        raiseOnDrag: false,
        draggable: true
    });
    marker.addEventListener("mouseover", function () {
        marker.setIcon(imageHover);
    });
    marker.addEventListener("mouseout", function () {
        marker.setIcon(imageNormalMidpoint);
    });
    marker.addEventListener("dragstart", function () {
        for (var i = 0; i < midmarkers.length; i++) {
            if (midmarkers[i] == marker) {
                var tmpPath = tmpPolyLine.getPath();
                tmpPath.push(markers[i].getPosition());
                tmpPath.push(midmarkers[i].getPosition());
                tmpPath.push(markers[i + 1].getPosition());
                break;
            }
        }
    });
    marker.addEventListener("drag", function () {
        for (var i = 0; i < midmarkers.length; i++) {
            if (midmarkers[i] == marker) {
                tmpPolyLine.getPath().setAt(1, marker.getPosition());
                break;
            }
        }
    });
    marker.addEventListener("dragend", function () {
        for (var i = 0; i < midmarkers.length; i++) {
            if (midmarkers[i] == marker) {
                var newpos = marker.getPosition();
                var startMarkerPos = markers[i].getPosition();
                var firstVPos = new BMap.Point(
                    newpos.lng - (0.5 * (newpos.lng - startMarkerPos.lng)),
                    newpos.lat - (0.5 * (newpos.lat - startMarkerPos.lat))
                );
                var endMarkerPos = markers[i + 1].getPosition();
                var secondVPos = new BMap.Point(
                    newpos.lng - (0.5 * (newpos.lng - endMarkerPos.lng)),
                    newpos.lat - (0.5 * (newpos.lat - endMarkerPos.lat))
                );
                var newVMarker = setmidmarkers(secondVPos, startMarkerPos);
                newVMarker.setPosition(secondVPos);//apply the correct position to the midmarker
                var newMarker = setmarkers(newpos);
                markers.splice(i + 1, 0, newMarker);
                polyShape.splice(i + 1, 0, newpos);
                marker.setPosition(firstVPos);
                midmarkers.splice(i + 1, 0, newVMarker);
                tmpPolyLine.getPath().splice(2, 1);
                tmpPolyLine.getPath().splice(1, 1);
                tmpPolyLine.getPath().splice(1, 1);
    			/*newpos = null;
    			startMarkerPos = null;
    			firstVPos = null;
    			endMarkerPos = null;
    			secondVPos = null;
    			newVMarker = null;
    			newMarker = null;*/
                break;
            }
        }
        polyPoints = polyShape.getPath();
        var stringtobesaved = '"' + newpos.lat.toFixed(6) + '","' + newpos.lng.toFixed(6) + '"';
        var kmlstringtobesaved = '"' + newpos.lng.toFixed(6) + '","' + newpos.lat.toFixed(6) + '"';
        pointsArray.splice(i + 1, 0, stringtobesaved);
        pointsArrayKml.splice(i + 1, 0, kmlstringtobesaved);
        logCode1();
    });
    return marker;
}
// Called from listener set in setmarkers
function movemidmarker(index) {
    var newpos = markers[index].getPosition();
    if (index != 0) {
        var prevpos = markers[index - 1].getPosition();
        midmarkers[index - 1].setPosition(new BMap.Point(
            newpos.lng - (0.5 * (newpos.lng - prevpos.lng)),
            newpos.lat - (0.5 * (newpos.lat - prevpos.lat))
        ));
        //prevpos = null;
    }
    if (index != markers.length - 1) {
        var nextpos = markers[index + 1].getPosition();
        midmarkers[index].setPosition(new BMap.Point(
            newpos.lng - (0.5 * (newpos.lng - nextpos.lng)),
            newpos.lat - (0.5 * (newpos.lat - nextpos.lat))
        ));
        //nextpos = null;
    }
    //newpos = null;
    //index = null;
}
// Called from listener set in setmarkers
function removemidmarker(index) {
    if (markers.length > 0) {//clicked marker has already been deleted
        if (index != markers.length) {
            map.removeOverlay(midmarkers[index]);
            midmarkers.splice(index, 1);
        } else {
            map.removeOverlay(midmarkers[index - 1]);
            midmarkers.splice(index - 1, 1);
        }
    }
    if (index != 0 && index != markers.length) {
        var prevpos = markers[index - 1].getPosition();
        var newpos = markers[index].getPosition();
        midmarkers[index - 1].setPosition(new BMap.Point(
            newpos.lng - (0.5 * (newpos.lng - nextpos.lng)),
            newpos.lat - (0.5 * (newpos.lat - prevpos.lat))
        ));
        //prevpos = null;
        //newpos = null;
    }
    //index = null;
}
function showKML() {
    if (codeID != 1) {
        codeID = gob('codechoice').value = 1; // set KML
        setCode();
    }
    gob('eGaaSCoords').value = kmlheading();
    for (var i = 0; i < placemarks.length; i++) {
        gob('eGaaSCoords').value += placemarks[i].plmtext;
    }
    gob('eGaaSCoords').value += kmlend();
}
function showAddress(address) {
    var encodedAddress = encodeURIComponent(address);
    var url = 'http://api.map.baidu.com/geocoder/v2/?output=json&address=' + encodedAddress + '&ak=27c88c00210c334dcad9c787e132d3df';
    $.get(url, function(result) {
        if (result.status === 0) {
            var pos = new BMap.Point(result.result.location.lng, result.result.location.lat);
            map.setCenter(pos);
            tinyMarker = new BMap.Marker(pos, {
                icon: tinyIcon
            });
            map.addOverlay(tinyMarker);
            drawnShapes.push(tinyMarker);
            if (directionsYes == 1) drawDirections(pos);
            if (toolID == 5) drawMarkers(pos);
        } else {
            alert(result.msg);
        }
    }, 'jsonp');
}
function getMapGeocode(coords, callback) {
    var lat = coords.cords[0][0];
    var lng = coords.cords[0][1];
    var url = 'http://api.map.baidu.com/geocoder/v2/?location=' + lat + ',' + lng + '&output=json&ak=27c88c00210c334dcad9c787e132d3df';
    $.get(url, function(response) {
        if (response.status === 0) {
            if (response.result.formatted_address) {
                callback(response.result.formatted_address);
            }
        } else {
            alert(response.msg);
        }
    }, 'jsonp');
}
function activateDirections() {
    directionsYes = 1;
    directionsintroduction();
}
function toggletext() {
    if (textsignal == 0) { //hide textpresentation
        closethis("presenter");
        notext = false; //no textfeed to hidden textarea
        showCodeintextarea();
        textsignal = 1;
    } else {
        showthis("presenter");
        notext = true;
        showCodeintextarea();
        textsignal = 0;
    }
}
function closethis(name) {
    //gob(name).style.visibility = 'hidden';
}
function showthis(name) {
    //gob(name).style.visibility = 'visible';
}
function docudetails() {
    if (directionsYes == 1) {
        if (dirline == null) dirline = plmcur;
        gob("dirplm1").value = placemarks[dirline].name;
        gob("dirplm2").value = placemarks[dirline].desc;
        gob("dirplm3").value = placemarks[dirline].tess;
        gob("dirplm4").value = placemarks[dirline].alt;
        if (plmcur > dirline) {
            gob("dirplm5").value = placemarks[plmcur].name;
            gob("dirplm6").value = placemarks[plmcur].desc;
        }
        gob("dirdoc1").value = docuname;
        gob("dirdoc2").value = docudesc;
        if (plmcur == dirline) {
            gob("dirplm5").disabled = true;
            gob("dirplm6").disabled = true;
        }
        showthis('dirtoppers');
        savedocudetails();
    } else {
        gob("plm1").value = placemarks[plmcur].name;
        gob("plm2").value = placemarks[plmcur].desc;
        gob("plm3").value = placemarks[plmcur].tess;
        gob("plm4").value = placemarks[plmcur].alt;
        gob("doc1").value = docuname;
        gob("doc2").value = docudesc;
        showthis('toppers');
    }
}
function savedocudetails() {
    if (directionsYes == 1) {
        placemarks[dirline].name = gob("dirplm1").value;
        placemarks[dirline].desc = gob("dirplm2").value;
        placemarks[dirline].tess = gob("dirplm3").value;
        placemarks[dirline].alt = gob("dirplm4").value;
        if (plmcur > dirline) {
            gob("dirplm5").disabled = false;
            gob("dirplm6").disabled = false;
            placemarks[plmcur].name = gob("dirplm5").value;
            placemarks[plmcur].desc = gob("dirplm6").value;
            markerShape.setTitle(placemarks[plmcur].name + "\n" + placemarks[plmcur].desc);
        }
        docuname = gob("dirdoc1").value;
        docudesc = gob("dirdoc2").value;
        logCode1a();
    } else {
        docuname = gob("doc1").value;
        docudesc = gob("doc2").value;
        placemarks[plmcur].name = gob("plm1").value;
        placemarks[plmcur].desc = gob("plm2").value;
        placemarks[plmcur].tess = gob("plm3").value;
        placemarks[plmcur].alt = gob("plm4").value;
        if (placemarks[plmcur].poly == "pl") logCode1();
        if (placemarks[plmcur].poly == "pg") logCode2();
    }
}
function mapzoom() {
    var mapZoom = map.getZoom();
    gob("myzoom").value = mapZoom;
}
function mapcenter() {
    var mapCenter = map.getCenter();
    var wrapped = new BMap.Point(mapCenter.lng, mapCenter.lat);
    var latLngStr = '"' + wrapped.lat.toFixed(6) + '","' + wrapped.lng.toFixed(6) + '"';
    //var latLngStr = mapCenter.lat.toFixed(6) + ', ' + mapCenter.lng.toFixed(6);
    gob("centerofmap").value = latLngStr;
}
function showCodeintextarea() {
    if (notext === false) {
        gob("presentcode").checked = false;
        notext = true;
    } else {
        gob("presentcode").checked = true;
        notext = false;
        if (polyPoints.length > 0) {
            if (toolID == 1) { // Polyline
                if (codeID == 1) logCode1();
                if (codeID == 2) logCode4();
            }
            if (toolID == 2) { // Polygon
                if (adder !== 0) { // with hole
                    adder = 0;
                    if (codeID == 1) logCode3();
                    if (codeID == 2) logCode5();
                } else {
                    if (codeID == 1) logCode2();
                    if (codeID == 2) logCode4();
                }
            }
            if (toolID == 3) { // Rectangle
                if (codeID == 2) logCode6();
                if (codeID == 1) logCode2();
            }
            if (toolID == 5) {  // Marker
                if (codeID == 1) logCode9();
            }
            if (toolID == 6) { // Directions
                if (codeID == 1) logCode1a();
            }
        }
        if (toolID == 4) { // Circle
            if (codeID == 2) logCode7();
        }
    }
}
// the copy part may not work with all web browsers
function copyTextarea() {
    gob('eGaaSCoords').focus();
    gob('eGaaSCoords').select();
    copiedTxt = document.selection.createRange();
    copiedTxt.execCommand("Copy");
}
function color_html2kml(color) {
    var newcolor = "FFFFFF";
    if (color.length == 7) newcolor = color.substring(5, 7) + color.substring(3, 5) + color.substring(1, 3);
    return newcolor;
}
function color_hex2dec(color) {
    var deccolor = "255,0,0";
    var dec1 = parseInt(color.substring(1, 3), 16);
    var dec2 = parseInt(color.substring(3, 5), 16);
    var dec3 = parseInt(color.substring(5, 7), 16);
    if (color.length == 7) deccolor = dec1 + ',' + dec2 + ',' + dec3;
    return deccolor;
}
function getopacityhex(opa) {
    var hexopa = "66";
    if (opa == 0) hexopa = "00";
    if (opa == .0) hexopa = "00";
    if (opa >= .1) hexopa = "1A";
    if (opa >= .2) hexopa = "33";
    if (opa >= .3) hexopa = "4D";
    if (opa >= .4) hexopa = "66";
    if (opa >= .5) hexopa = "80";
    if (opa >= .6) hexopa = "9A";
    if (opa >= .7) hexopa = "B3";
    if (opa >= .8) hexopa = "CD";
    if (opa >= .9) hexopa = "E6";
    if (opa == 1.0) hexopa = "FF";
    if (opa == 1) hexopa = "FF";
    return hexopa;
}
function iconoptions(chosenicon) {
    gob("st2").value = chosenicon;
    gob("currenticon").innerHTML = '<img src="' + chosenicon + '" alt="" />';
}
// Called from button 'Style Options'
function styleprep() {
    if (gob('toolchoice').value == 6) toolID = 6;
    styleoptions();
}
// Called from styleprep, stepstyles and links in div directionstyles
// If coming from directionstyles, toolID=6 has been changed to 1 or 5
function styleoptions() { //present current style in ..options
    closethis('polylineoptions');
    closethis('polygonoptions');
    //closethis('rectang');
    closethis('circleoptions');
    closethis('markeroptions');
    closethis('directionstyles');
    if (toolID == 1) {
        showthis('polylineoptions'); // Edit style or create new style if sent to polylinestyle()
        //if(plmcur<placemarks.length-1) lcur = placemarks[plmcur].stylecur;
        gob('polylineinput1').value = polylinestyles[lcur].color;
        gob('polylineinput2').value = polylinestyles[lcur].lineopac;
        gob('polylineinput3').value = polylinestyles[lcur].width;
        gob('polylineinput4').value = polylinestyles[lcur].name;
        gob("stylenumberl").innerHTML = (lcur + 1) + ' ';
    }
    if (toolID == 2 || toolID == 3) {
        showthis('polygonoptions');
        //if(plmcur<placemarks.length-1) pcur = placemarks[plmcur].stylecur;
        gob('polygoninput1').value = polygonstyles[pcur].color;
        gob('polygoninput2').value = polygonstyles[pcur].lineopac;
        gob('polygoninput3').value = polygonstyles[pcur].width;
        gob('polygoninput4').value = polygonstyles[pcur].fill;
        gob('polygoninput5').value = polygonstyles[pcur].fillopac;
        gob('polygoninput6').value = polygonstyles[pcur].name;
        gob("stylenumberp").innerHTML = (pcur + 1) + ' ';
    }
    if (toolID == 4) {
        showthis('circleoptions');
        gob('circinput1').value = circlestyles[ccur].color;
        gob('circinput2').value = circlestyles[ccur].lineopac;
        gob('circinput3').value = circlestyles[ccur].width;
        gob('circinput4').value = circlestyles[ccur].fill;
        gob('circinput5').value = circlestyles[ccur].fillopac;
        gob('circinput6').value = circlestyles[ccur].name;
        gob("stylenumberc").innerHTML = (ccur + 1) + ' ';
    }
    if (toolID == 5) {
        showthis('markeroptions');
        gob('st1').value = markerstyles[mcur].name;
        iconoptions(markerstyles[mcur].icon);
        gob("stylenumberm").innerHTML = (mcur + 1) + ' ';
    }
    if (toolID == 6) {
        showthis('directionstyles');
    }
}
// Called from links in polylineoptions. If Directionsmode, toolID will be changed back to 6
function polylinestyle(e) { //save style
    if (e == 1) {
        createlinestyleobject();
        lcur++;
    }
    polylinestyles[lcur].name = gob('polylineinput4').value;
    if (e == 1) {
        if (polylinestyles[lcur].name == polylinestyles[lcur - 1].name) {
            lcur--;
            polylinestyles.pop();
            alert("Give the new style a new name");
            return;
        }
    }
    polylinestyles[lcur].color = gob('polylineinput1').value;
    polylineDecColorCur = color_hex2dec(polylinestyles[lcur].color);
    polylinestyles[lcur].lineopac = gob('polylineinput2').value;
    if (polylinestyles[lcur].lineopac < 0 || polylinestyles[lcur].lineopac > 1) return alert('Opacity must be between 0 and 1');
    polylinestyles[lcur].width = gob('polylineinput3').value;
    if (polylinestyles[lcur].width < 0 || polylinestyles[lcur].width > 20) return alert('Numbers below zero and above 20 are not accepted');
    polylinestyles[lcur].kmlcolor = getopacityhex(polylinestyles[lcur].lineopac) + color_html2kml("" + polylinestyles[lcur].color);
    if (directionsYes == 1) {
        placemarks[dirline].style = polylinestyles[lcur].name;
        placemarks[dirline].stylecur = lcur;
    } else {
        placemarks[plmcur].style = polylinestyles[lcur].name;
        placemarks[plmcur].stylecur = lcur;
    }
    gob("stylenumberl").innerHTML = (lcur + 1) + ' ';
    if (polyShape) map.removeOverlay(polyShape);
    preparePolyline();
    if (directionsYes == 1) {
        toolID = 6;
    }
    if (polyPoints.length > 0) {
        if (toolID == 6) {
            logCode1a();
        } else {
            if (codeID == 1) logCode1();
            if (codeID == 2) logCode4();
        }
    } else {
        alert("SAVED!");
    }
}
function polygonstyle(e) {
    if (e == 1) {
        createpolygonstyleobject();
        pcur++;
    }
    polygonstyles[pcur].name = gob('polygoninput6').value;
    if (e == 1) {
        if (polygonstyles[pcur].name == polygonstyles[pcur - 1].name) {
            pcur--;
            polygonstyles.pop();
            alert("Give the new style a new name");
            return;
        }
    }
    polygonstyles[pcur].color = gob('polygoninput1').value;
    polygonDecColorCur = color_hex2dec(polygonstyles[pcur].color);
    polygonstyles[pcur].lineopac = gob('polygoninput2').value;
    if (polygonstyles[pcur].lineopac < 0 || polygonstyles[pcur].lineopac > 1) return alert('Opacity must be between 0 and 1');
    polygonstyles[pcur].width = gob('polygoninput3').value;
    if (polygonstyles[pcur].width < 0 || polygonstyles[pcur].width > 20) return alert('Numbers below zero and above 20 are not accepted');
    polygonstyles[pcur].fill = gob('polygoninput4').value;
    polygonFillDecColorCur = color_hex2dec(polygonstyles[pcur].fill);
    polygonstyles[pcur].fillopac = gob('polygoninput5').value;
    if (polygonstyles[pcur].fillopac < 0 || polygonstyles[pcur].fillopac > 1) return alert('Opacity must be between 0 and 1');
    polygonstyles[pcur].kmlcolor = getopacityhex(polygonstyles[pcur].lineopac) + color_html2kml("" + polygonstyles[pcur].color);
    polygonstyles[pcur].kmlfill = getopacityhex(polygonstyles[pcur].fillopac) + color_html2kml("" + polygonstyles[pcur].fill);
    placemarks[plmcur].style = polygonstyles[pcur].name;
    placemarks[plmcur].stylecur = pcur;
    gob("stylenumberp").innerHTML = (pcur + 1) + ' ';
    if (polyShape) map.removeOverlay(polyShape);
    if (outerShape) map.removeOverlay(outerShape);
    if (holePolyArray.length > 0) {
        drawpolywithhole();
        if (codeID == 1) logCode3();
        if (codeID == 2) logCode5();
    }
    if (holePolyArray.length == 0) {
        preparePolygon();
        if (polyPoints.length > 0) {
            if (codeID == 1) logCode2();
            if (codeID == 2) logCode4();
        } else {
            alert("SAVED!");
        }
    }
}

function circlestyle(e) {
    if (e == 1) {
        createcirclestyleobject();
        ccur++;
    }
    circlestyles[ccur].name = gob('circinput6').value;
    if (e == 1) {
        if (circlestyles[ccur].name == circlestyles[ccur - 1].name) {
            ccur--;
            circlestyles.pop();
            alert("Give the new style a new name");
            return;
        }
    }
    circlestyles[ccur].color = gob('circinput1').value;
    circlestyles[ccur].lineopac = gob('circinput2').value;
    if (circlestyles[ccur].lineopac < 0 || circlestyles[ccur].lineopac > 1) return alert('Opacity must be between 0 and 1');
    circlestyles[ccur].width = gob('circinput3').value;
    circlestyles[ccur].fill = gob('circinput4').value;
    circlestyles[ccur].fillopac = gob('circinput5').value;
    if (circlestyles[ccur].fillopac < 0 || circlestyles[ccur].fillopac > 1) return alert('Opacity must be between 0 and 1');
    placemarks[plmcur].style = circlestyles[ccur].name;
    placemarks[plmcur].stylecur = ccur;
    gob("stylenumberc").innerHTML = (ccur + 1) + ' ';
    if (circle) map.removeOverlay(circle);
    activateCircle();
    if (radiusPoint) {
        drawCircle();
        logCode7();
    } else {
        alert("SAVED!");
    }
}
function markerstyle(e) {
    if (e == 1) {
        createmarkerstyleobject();
        mcur++;
    }
    markerstyles[mcur].name = gob('st1').value;
    if (e == 1) {
        if (markerstyles[mcur].name == markerstyles[mcur - 1].name) {
            mcur--;
            markerstyles.pop();
            alert("Give the new style a new name");
            return;
        }
    }
    markerstyles[mcur].icon = gob('st2').value;
    placemarks[plmcur].style = markerstyles[mcur].name;
    placemarks[plmcur].stylecur = mcur;
    gob("stylenumberm").innerHTML = (mcur + 1) + ' ';
    if (directionsYes == 1) toolID = 6;
    if (markerShape) {
        markerShape.setIcon(markerstyles[mcur].icon);
        if (toolID == 6) {
            logCode1a();
        } else {
            if (codeID == 1) logCode9();
            if (codeID == 2) logCode8();
        }
    } else {
        alert("SAVED!");
    }
}
function stepstyles(a) {
    if (directionsYes == 1) {
        if (gob('polylineoptions').style.visibility == 'visible') {
            toolID = 1;
        } else {
            toolID = 5;
        }
    }
    if (toolID == 1) {
        if (a == -1) {
            if (lcur > 0) {
                lcur--;
                gob("stylenumberl").innerHTML = (lcur + 1) + ' ';
                styleoptions();
            }
        }
        if (a == 1) {
            if (lcur < polylinestyles.length - 1) {
                lcur++;
                gob("stylenumberl").innerHTML = (lcur + 1) + ' ';
                styleoptions();
            }
        }
        if (directionsYes == 1) {
            placemarks[dirline].style = polylinestyles[lcur].name;
            placemarks[dirline].stylecur = lcur;
        } else {
            placemarks[plmcur].style = polylinestyles[lcur].name;
            placemarks[plmcur].stylecur = lcur;
        }
        if (polyShape) map.removeOverlay(polyShape);
        preparePolyline();
        if (directionsYes == 1) {
            toolID = 6;
        }
        if (polyPoints.length > 0) {
            if (toolID == 6) {
                logCode1a();
            } else {
                if (codeID == 1) logCode1();
                if (codeID == 2) logCode4();
            }
        }
    }
    if (toolID == 2 || toolID == 3) {
        if (a == -1) {
            if (pcur > 0) {
                pcur--;
                gob("stylenumberp").innerHTML = (pcur + 1) + ' ';
                styleoptions();
            }
        }
        if (a == 1) {
            if (pcur < polygonstyles.length - 1) {
                pcur++;
                gob("stylenumberp").innerHTML = (pcur + 1) + ' ';
                styleoptions();
            }
        }
        placemarks[plmcur].style = polygonstyles[pcur].name;
        placemarks[plmcur].stylecur = pcur;
        if (polyShape) {
            //alert("polyShape");
            map.removeOverlay(polyShape);
            preparePolygon();
            if (polyPoints.length) {
                if (codeID == 1) logCode2();
                if (codeID == 2) logCode4();
            }
        }
        /*if(rectangle) {
            //alert("polyShape");
            map.removeOverlay(rectangle);
            activateRectangle();
            if(polyPoints.length) {
                if(codeID == 1) logCode2();
                if(codeID == 2) logCode4();
            }
        }*/
    }
    if (toolID == 4) {
        if (a == -1) {
            if (ccur > 0) {
                ccur--;
                gob("stylenumberc").innerHTML = (ccur + 1) + ' ';
                styleoptions();
            }
        }
        if (a == 1) {
            if (ccur < circlestyles.length - 1) {
                ccur++;
                gob("stylenumberc").innerHTML = (ccur + 1) + ' ';
                styleoptions();
            }
        }
        placemarks[plmcur].style = circlestyles[ccur].name;
        placemarks[plmcur].stylecur = ccur;
        if (circle) map.removeOverlay(circle);
        activateCircle();
        if (radiusPoint) {
            logCode7();
        }
    }
    if (toolID == 5) {
        if (a == -1) {
            if (mcur > 0) {
                mcur--;
                gob("stylenumberm").innerHTML = (mcur + 1) + ' ';
                styleoptions();
            }
        }
        if (a == 1) {
            if (mcur < markerstyles.length - 1) {
                mcur++;
                gob("stylenumberm").innerHTML = (mcur + 1) + ' ';
                styleoptions();
            }
        }
        placemarks[plmcur].style = markerstyles[mcur].name;
        placemarks[plmcur].stylecur = mcur;
        if (directionsYes == 1) toolID = 6;
        if (markerShape) {
            markerShape.setIcon(markerstyles[mcur].icon);
            if (toolID == 6) {
                logCode1a();
            } else {
                if (codeID == 1) logCode9();
                if (codeID == 2) logCode8();
            }
        }
    }
}
function kmlheading() {
    var heading = "";
    var styleforpolygon = "";
    var styleforrectangle = "";
    var styleforpolyline = "";
    var styleformarker = "";
    var i;
    heading = '<?xml version="1.0" encoding="UTF-8"?>\n' +
        '<kml xmlns="http://www.opengis.net/kml/2.2">\n' +
        '<Document><name>' + docuname + '</name>\n' +
        '<description>' + docudesc + '</description>\n';
    for (i = 0; i < polygonstyles.length; i++) {
        styleforpolygon += '<Style id="' + polygonstyles[i].name + '">\n' +
            '<LineStyle><color>' + polygonstyles[i].kmlcolor + '</color><width>' + polygonstyles[i].width + '</width></LineStyle>\n' +
            '<PolyStyle><color>' + polygonstyles[i].kmlfill + '</color></PolyStyle>\n' +
            '</Style>\n';
    }
    for (i = 0; i < polylinestyles.length; i++) {
        styleforpolyline += '<Style id="' + polylinestyles[i].name + '">\n' +
            '<LineStyle><color>' + polylinestyles[i].kmlcolor + '</color><width>' + polylinestyles[i].width + '</width></LineStyle>\n' +
            '</Style>\n';
    }
    for (i = 0; i < markerstyles.length; i++) {
        styleformarker += '<Style id="' + markerstyles[i].name + '">\n' +
            '<IconStyle><Icon><href>\n' + markerstyles[i].icon + '\n</href></Icon></IconStyle>\n' +
            '</Style>\n';
    }
    return heading + styleforpolygon + styleforpolyline + styleformarker;
}
function kmlend() {
    var ending;
    return ending = '</Document>\n</kml>';
}
// write kml for polyline in text area
function logCode1() {
    if (notext === true) return;
    var code = ""; // placemarks[plmcur].style = polylinestyles[lcur].name
    var kmltext1 = '<Placemark><name>' + placemarks[plmcur].name + '</name>\n' +
        '<description>' + placemarks[plmcur].desc + '</description>\n' +
        '<styleUrl>#' + placemarks[plmcur].style + '</styleUrl>\n' +
        '<LineString>\n<tessellate>' + placemarks[plmcur].tess + '</tessellate>\n' +
        '<altitudeMode>' + placemarks[plmcur].alt + '</altitudeMode>\n<coordinates>\n';
    for (var i = 0; i < pointsArrayKml.length; i++) {
        code += pointsArrayKml[i] + ',0.0 \n';
    }
    kmltext2 = '</coordinates>\n</LineString>\n</Placemark>\n';
    placemarks[plmcur].plmtext = kmlcode = kmltext1 + code + kmltext2;
    placemarks[plmcur].poly = "pl";
    placemarks[plmcur].jscode = pointsArray;
    placemarks[plmcur].kmlcode = pointsArrayKml;
    gob('eGaaSCoords').value = kmlheading() + kmltext1 + code + kmltext2 + kmlend();
}
// write kml for Directions in text area
function logCode1a() {
    if (notext === true) return;
    gob('eGaaSCoords').value = "";
    var code = "";
    //var kmlMarker = "";
    //var kmlMarkers = "";
    var kmltext1 = '<Placemark><name>' + placemarks[dirline].name + '</name>\n' +
        '<description>' + placemarks[dirline].desc + '</description>\n' +
        '<styleUrl>#' + placemarks[dirline].style + '</styleUrl>\n' +
        '<LineString>\n<tessellate>' + placemarks[dirline].tess + '</tessellate>\n' +
        '<altitudeMode>' + placemarks[dirline].alt + '</altitudeMode>\n<coordinates>\n';
    if (pointsArrayKml.length != 0) {
        for (var i = 0; i < pointsArrayKml.length; i++) {
            code += pointsArrayKml[i] + ',0.0 \n';
        }
        placemarks[dirline].jscode = pointsArray;
        placemarks[dirline].kmlcode = pointsArrayKml;
    }
    kmltext2 = '</coordinates>\n</LineString>\n</Placemark>\n';
    placemarks[dirline].plmtext = kmltext1 + code + kmltext2;
    placemarks[dirline].poly = "pl";
    gob('eGaaSCoords').value = kmlheading() + kmltext1 + code + kmltext2;

    if (markersArrayKml.length != 0) {
        for (i = 0; i < markersArrayKml.length; i++) {
            var kmlMarker = "";
            var m = dirline + 1;
            kmlMarker += '<Placemark><name>' + placemarks[m + i].name + '</name>\n' +
                '<description>' + addresssArray[i] + '</description>\n' +
                '<styleUrl>#' + placemarks[m + i].style + '</styleUrl>\n' +
                '<Point>\n<coordinates>';
            kmlMarker += markersArrayKml[i] + ',0.0';
            kmlMarker += '</coordinates>\n</Point>\n</Placemark>\n';
            placemarks[m + i].jscode = markersArray[i];
            placemarks[m + i].kmlcode = markersArrayKml[i];
            placemarks[m + i].plmtext = kmlMarker;
            gob('eGaaSCoords').value += kmlMarker;
        }
    }
    //placemarks[dirline].plmtext = kmlcode = kmltext1+code+kmltext2+kmlMarkers;
    gob('eGaaSCoords').value += kmlend();
}
// write kml for polygon in text area
function logCode2() {
    if (notext === true) return;
    var code = "";
    var kmltext1 = '<Placemark><name>' + placemarks[plmcur].name + '</name>\n' +
        '<description>' + placemarks[plmcur].desc + '</description>\n' +
        '<styleUrl>#' + placemarks[plmcur].style + '</styleUrl>\n' +
        '<Polygon>\n<tessellate>' + placemarks[plmcur].tess + '</tessellate>\n' +
        '<altitudeMode>' + placemarks[plmcur].alt + '</altitudeMode>\n' +
        '<outerBoundaryIs><LinearRing><coordinates>\n';
    if (pointsArrayKml.length != 0) {
        for (var i = 0; i < pointsArrayKml.length; i++) {
            code += pointsArrayKml[i] + ',0.0 \n';
        }
        code += pointsArrayKml[0] + ',0.0 \n';
        placemarks[plmcur].jscode = pointsArray;
        placemarks[plmcur].kmlcode = pointsArrayKml;
    }
    kmltext2 = '</coordinates></LinearRing></outerBoundaryIs>\n</Polygon>\n</Placemark>\n';
    placemarks[plmcur].plmtext = kmlcode = kmltext1 + code + kmltext2;
    placemarks[plmcur].poly = "pg";
    gob('eGaaSCoords').value = kmlheading() + kmltext1 + code + kmltext2 + kmlend();
}
// write kml for polygon with hole
function logCode3() {
    if (notext === true) return;
    var code = "";
    var kmltext = '<Placemark><name>' + placemarks[plmcur].name + '</name>\n' +
        '<description>' + placemarks[plmcur].desc + '</description>\n' +
        '<styleUrl>#' + placemarks[plmcur].style + '</styleUrl>\n' +
        '<Polygon>\n<tessellate>' + placemarks[plmcur].tess + '</tessellate>\n' +
        '<altitudeMode>' + placemarks[plmcur].alt + '</altitudeMode>\n' +
        '<outerBoundaryIs><LinearRing><coordinates>\n';
    for (var i = 0; i < outerArrayKml.length; i++) {
        kmltext += outerArrayKml[i] + ',0.0 \n';
        code += outerArrayKml[i] + ',0.0 \n';
    }
    kmltext += outerArrayKml[0] + ',0.0 \n';
    code += outerArrayKml[0] + ',0.0 \n';
    placemarks[plmcur].jscode = pointsArray;
    placemarks[plmcur].kmlcode = outerArrayKml;
    placemarks[plmcur].kmlholecode = innerArraysKml;
    placemarks[plmcur].poly = "pgh";
    kmltext += '</coordinates></LinearRing></outerBoundaryIs>\n';
    for (var m = 0; m < innerArraysKml.length; m++) {
        kmltext += '<innerBoundaryIs><LinearRing><coordinates>\n';
        for (var i = 0; i < innerArraysKml[m].length; i++) {
            kmltext += innerArraysKml[m][i] + ',0.0 \n';
        }
        kmltext += innerArraysKml[m][0] + ',0.0 \n';
        kmltext += '</coordinates></LinearRing></innerBoundaryIs>\n';
    }
    kmltext += '</Polygon>\n</Placemark>\n';
    placemarks[plmcur].plmtext = kmlcode = kmltext;
    gob('eGaaSCoords').value = kmlheading() + kmltext + kmlend();
}
// write javascript
function logCode4() {
    if (notext === true) return;
    gob('eGaaSCoords').value = '';
    for (var i = 0; i < pointsArray.length; i++) {
        if (i == pointsArray.length - 1) {
            //gob('eGaaSCoords').value += 'new BMap.Point('+pointsArray[i] + ')\n';
            gob('eGaaSCoords').value += '[' + pointsArray[i] + ']';
        } else {
            //gob('eGaaSCoords').value += 'new BMap.Point('+pointsArray[i] + '),\n';
            gob('eGaaSCoords').value += '[' + pointsArray[i] + '],';
        }
    }
    if (toolID == 1) {
        gob('eGaaSCoords').value += '];\n';
        var options = 'var polyOptions = {\n'
            + 'strokeColor: "' + polylinestyles[lcur].color + '",\n'
            + 'strokeOpacity: ' + polylinestyles[lcur].lineopac + ',\n'
            + 'strokeWeight: ' + polylinestyles[lcur].width + '\n'
            + '}\n';
        gob('eGaaSCoords').value += options;
        gob('eGaaSCoords').value += 'var it = new BMap.Polyline(myCoordinates, polyOptions);\n'
            + 'map.addOverlay(it);\n';
        placemarks[plmcur].poly = "pl";
    }
    if (toolID == 2) {
        gob('eGaaSCoords').value += '';/* += '];\n';
        var options = 'var polyOptions = {\n'
        +'strokeColor: "'+polygonstyles[pcur].color+'",\n'
        +'strokeOpacity: '+polygonstyles[pcur].lineopac+',\n'
        +'strokeWeight: '+polygonstyles[pcur].width+',\n'
        +'fillColor: "'+polygonstyles[pcur].fill+'",\n'
        +'fillOpacity: '+polygonstyles[pcur].fillopac+'\n'
        +'}\n';
        gob('eGaaSCoords').value += options;
        gob('eGaaSCoords').value +='var it = new BMap.Polygon(myCoordinates, polyOptions);\n'
        +'map.addOverlay(it);\n';
        placemarks[plmcur].poly = "pg";*/
    }
    javacode = gob('eGaaSCoords').value;
}
// write javascript for polygon with hole
function logCode5() {
    if (notext === true) return;
    var hstring = "";
    gob('eGaaSCoords').value = 'var outerPoints = [\n';
    for (var i = 0; i < outerArray.length; i++) {
        if (i == outerArray.length - 1) {
            gob('eGaaSCoords').value += 'new BMap.Point(' + outerArray[i] + ')\n'; // without trailing comma
        } else {
            gob('eGaaSCoords').value += 'new BMap.Point(' + outerArray[i] + '),\n';
        }
    }
    gob('eGaaSCoords').value += '];\n';
    for (var m = 0; m < innerArrays.length; m++) {
        gob('eGaaSCoords').value += 'var innerPoints' + m + ' = [\n';
        var holestring = 'innerPoints' + m;
        if (m < innerArrays.length - 1) holestring += ',';
        hstring += holestring;
        for (i = 0; i < innerArrays[m].length; i++) {
            if (i == innerArrays[m].length - 1) {
                gob('eGaaSCoords').value += 'new BMap.Point(' + innerArrays[m][i] + ')\n';
            } else {
                gob('eGaaSCoords').value += 'new BMap.Point(' + innerArrays[m][i] + '),\n';
            }
        }
        gob('eGaaSCoords').value += '];\n';
    }
    gob('eGaaSCoords').value += 'var myCoordinates = [outerPoints,' + hstring + '];\n';
    gob('eGaaSCoords').value += 'var polyOptions = {\n'
        + 'strokeColor: "' + polygonstyles[pcur].color + '",\n'
        + 'strokeOpacity: ' + polygonstyles[pcur].lineopac + ',\n'
        + 'strokeWeight: ' + polygonstyles[pcur].width + ',\n'
        + 'fillColor: "' + polygonstyles[pcur].fill + '",\n'
        + 'fillOpacity: ' + polygonstyles[pcur].fillopac + '\n'
        + '};\n'
        + 'var it = new BMap.Polygon(myCoordinates, polyOptions);\n'
        + 'map.addOverlay(it);\n';
    placemarks[plmcur].poly = "pgh";
    javacode = gob('eGaaSCoords').value;
}
// write javascript or kml for rectangle
function logCode6() {
    if (notext === true) return;
    //placemarks[plmcur].style = polygonstyles[pcur].name;
    if (codeID == 2) { // javascript
        gob('eGaaSCoords').value = 'var rectangle = new BMap.Polygon([], {\n'
            + 'fillColor: ' + polygonstyles[pcur].fill + ',\n'
            + 'fillOpacity: ' + polygonstyles[pcur].fillopac + ',\n'
            + 'strokeColor: ' + polygonstyles[pcur].color + ',\n'
            + 'strokeOpacity: ' + polygonstyles[pcur].lineopac + ',\n'
            + 'strokeWeight: ' + polygonstyles[pcur].width + '\n'
            + '});\n';
        gob('eGaaSCoords').value += 'var sWest = new BMap.Point(' + southWest.lng.toFixed(6) + ',' + southWest.lat.toFixed(6) + ');\n'
            + 'var nEast = new BMap.Point(' + northEast.lng.toFixed(6) + ',' + northEast.lat.toFixed(6) + ');\n'
            + 'var bounds = new BMap.Bounds(sWest,nEast);\n'
            + 'setRectangleBounds(rectangle, bounds);;\n';
        gob('eGaaSCoords').value += '\n\\\\ Code for polyline rectangle\n';
        gob('eGaaSCoords').value += 'var myCoordinates = [\n';
        gob('eGaaSCoords').value += southWest.lat.toFixed(6) + ',' + southWest.lng.toFixed(6) + ',\n' +
            southWest.lat.toFixed(6) + ',' + northEast.lng.toFixed(6) + ',\n' +
            northEast.lat.toFixed(6) + ',' + northEast.lng.toFixed(6) + ',\n' +
            northEast.lat.toFixed(6) + ',' + southWest.lng.toFixed(6) + ',\n' +
            southWest.lat.toFixed(6) + ',' + southWest.lng.toFixed(6) + '\n';
        gob('eGaaSCoords').value += '];\n';
        var options = 'var polyOptions = {\n'
            + 'strokeColor: "' + polygonstyles[pcur].color + '",\n'
            + 'strokeOpacity: ' + polygonstyles[pcur].lineopac + ',\n'
            + 'strokeWeight: ' + polygonstyles[pcur].width + '\n'
            + '}\n';
        gob('eGaaSCoords').value += options;
        gob('eGaaSCoords').value += 'var it = new BMap.Polyline(myCoopolyOptions, polyOptions);\n'
            + 'map.addOverlay(it);\n';
        javacode = gob('eGaaSCoords').value;
    }
    if (codeID == 1) { // kml
        var kmltext = '<Placemark><name>' + placemarks[plmcur].name + '</name>\n' +
            '<description>' + placemarks[plmcur].desc + '</description>\n' +
            '<styleUrl>#' + placemarks[plmcur].style + '</styleUrl>\n' +
            '<Polygon>\n<tessellate>' + placemarks[plmcur].tess + '</tessellate>\n' +
            '<altitudeMode>' + placemarks[plmcur].alt + '</altitudeMode>\n' +
            '<outerBoundaryIs><LinearRing><coordinates>\n';
        kmltext += southWest.lng.toFixed(6) + ',' + southWest.lat.toFixed(6) + ',0.0 \n' +
            southWest.lng.toFixed(6) + ',' + northEast.lat.toFixed(6) + ',0.0 \n' +
            northEast.lng.toFixed(6) + ',' + northEast.lat.toFixed(6) + ',0.0 \n' +
            northEast.lng.toFixed(6) + ',' + southWest.lat.toFixed(6) + ',0.0 \n' +
            southWest.lng.toFixed(6) + ',' + southWest.lat.toFixed(6) + ',0.0 \n';
        kmltext += '</coordinates></LinearRing></outerBoundaryIs>\n</Polygon>\n</Placemark>\n';
        placemarks[plmcur].plmtext = kmlcode = kmltext;
        gob('eGaaSCoords').value = kmlheading() + kmltext + kmlend();
    }
}
function logCode7() { // javascript for circle
    if (notext === true) return;
    //placemarks[plmcur].style = circlestyles[ccur].name;
    gob('eGaaSCoords').value = 'var circle = new BMap.Circle(new BMap.Point(' + centerPoint.lng.toFixed(6) + ',' + centerPoint.lat.toFixed(6) + '), 0, {\n'
        + 'fillColor: ' + circlestyles[ccur].fill + ',\n'
        + 'fillOpacity: ' + circlestyles[ccur].fillopac + ',\n'
        + 'strokeColor: ' + circlestyles[ccur].color + ',\n'
        + 'strokeOpacity: ' + circlestyles[ccur].lineopac + ',\n'
        + 'strokeWeight: ' + circlestyles[ccur].width + '\n'
        + '});\n';
    gob('eGaaSCoords').value += 'circle.setRadius(' + calc + ');\n';
    javacode = gob('eGaaSCoords').value;
}
function logCode8() { //javascript for Marker
    if (notext === true) return;
    var text = 'var image = \'' + markerstyles[mcur].icon + '\';\n'
        + 'var marker = new BMap.Marker(' + placemarks[plmcur].point + ', {\n'
        + 'icon: image\n'
        + '});\n'
        + '//Your content for the infowindow\n'
        + 'var html = \'<b>' + placemarks[plmcur].name + '</b> <br/>' + placemarks[plmcur].desc + '\';';
    gob('eGaaSCoords').value = text;
    javacode = gob('eGaaSCoords').value;
}
function logCode9() { //KML for marker
    if (notext === true) return;
    gob('eGaaSCoords').value = "";
    var kmlMarkers = "";
    kmlMarkers += '<Placemark><name>' + placemarks[plmcur].name + '</name>\n' +
        '<description>' + placemarks[plmcur].desc + '</description>\n' +
        '<styleUrl>#' + placemarks[plmcur].style + '</styleUrl>\n' +
        '<Point>\n<coordinates>';
    kmlMarkers += placemarks[plmcur].kmlcode + ',0.0';
    kmlMarkers += '</coordinates>\n</Point>\n</Placemark>\n';
    //placemarks[plmcur].poly = "pl";
    placemarks[plmcur].plmtext = kmlcode = kmlMarkers;
    gob('eGaaSCoords').value = kmlheading() + kmlMarkers + kmlend();
}


function directionsintroduction() {
    gob('eGaaSCoords').value;
}
function markerintroduction() {
    gob('eGaaSCoords').value;
}
function polylineintroduction() {
    gob('eGaaSCoords').value;
}
function polygonintroduction() {
    gob('eGaaSCoords').value;
}
function rectangleintroduction() {
    gob('eGaaSCoords').value;
}
function circleintroduction() {
    gob('eGaaSCoords').value;
}

var StateCoords = [];
var StateCenterX = 0;
var StateCenterY = 0;
var StateZoom = 0;

function regMap(coords, render) {
    var container = $("#map_canvas").parent();
    StateCoords = [];

    if (coords != "") {
        coords = JSON.parse(coords);
        container.show();

        var StatePoints = coords.cords;
        var latlng = {};

        StateZoom = Number(coords.zoom);
        StateCenterX = Number(coords.center_point[0]);
        StateCenterY = Number(coords.center_point[1]);

        for (var i in StatePoints) {
            latlng = { lat: Number(StatePoints[i][0]), lng: Number(StatePoints[i][1]) };
            StateCoords.push(latlng);
        }

        if (render != false) {
            var map = new BMap.Map('map_canvas', {
                mapType: BMAP_NORMAL_MAP
            });
            map.enableScrollWheelZoom();
            map.centerAndZoom(new BMap.Point(StateCenterY, StateCenterX), StateZoom);
            var State = new BMap.Polygon(StateCoords, {
                strokeColor: '#FF0000',
                strokeOpacity: 0.8,
                strokeWeight: 2,
                fillColor: '#0000FF',
                fillOpacity: 0.6
            });
            map.addOverlay(State);
        }
    } else {
        container.hide();
    }
}

var newCoordsContainer;
var newAddressContainer;
var newAreaContainer;

function openMap(container, address, area) {
    StateCoords = [];
    newCoordsContainer = $("#" + container);
	newAddressContainer = address ? address : container + "_address";
	newAreaContainer = area ? area : container + "_area";
	
    var modal = $("#modal_map");
    updateLanguage("#modal_map .lang");

    if (!newCoordsContainer.val() == "") {
        try {
            regMap(newCoordsContainer.val(), false);
        } catch (e) {
            Alert(e.name, e.message, "error");
            return false;
        }

        modal.modal("show");
        modal.on('shown.bs.modal', function (e) {
            initmap();
            clearMap();
            $("#toolchoice, #codechoice").change();
        });
    } else {
        StateZoom = 7;
        StateCenterX = 23.907173;
        StateCenterY = 54.333531;

        modal.modal("show");
        modal.on('shown.bs.modal', function (e) {
            initmap();
            clearMap();
            $("#toolchoice, #codechoice").change();
        });
    }
}

function saveMap() {
    mapcenter();
    mapzoom();

    var center = '{"center_point":[' + $("#centerofmap").val() + '], ';
    var zoom = '"zoom":"' + $("#myzoom").val() + '", ';
    var points = '"cords":[' + $("#eGaaSCoords").val() + ']}';

    newCoordsContainer.val(center + zoom + points);

    if (!$("#" + newAddressContainer).length) {
        $('<div class="form-group"> <label>Address</label><input id="' + newAddressContainer + '" class="form-control" type="text"></div>').insertAfter(newCoordsContainer.parent());
    }
	
	if (!$("#" + newAreaContainer).length) {
		$('<div class="form-group"> <label>Area (sq meters)</label><input id="' + newAreaContainer + '" class="form-control" type="text"></div>').insertAfter(newCoordsContainer.parent());
    }
	
	setTimeout(function(){
		getMapAddress($("#" + newAddressContainer), JSON.parse(newCoordsContainer.val()));
		getMapAddressSquare($("#" + newAreaContainer), JSON.parse(newCoordsContainer.val()));
	}, 0)
}

function miniMap(elem, width, height) {
    $("." + elem).css({ "font-size": "0px" });

    $("." + elem).each(function () {
        var data = {};
        var miniPoints = [];
        var miniCoords = [];
        var miniCenterX = 0;
        var miniCenterY = 0;
        var miniZoom = 0;
        var latlng = {};
        var mapType = getMapType($(this).attr('maptype'));
        var mapHeight = $(this).attr('hmap');
        if (mapHeight)
            mapHeight += 'px';
        else
            mapHeight = height;
        if ($(this).text()) {
            if ($(this).parents("[class*='col-']")) {
                $(this).addClass("panel");
            }

            ++miniMapNum;
            data = JSON.parse($(this).text());
            miniPoints = data.cords;
            miniZoom = Number(data.zoom);
            miniCenterX = Number(data.center_point[0]);
            miniCenterY = Number(data.center_point[1]);

            for (var i in miniPoints) {
                latlng = { lat: Number(miniPoints[i][0]), lng: Number(miniPoints[i][1]) };
                miniCoords.push(latlng);
            }

            $(this).text("");
            var canvas = document.createElement('div');
            var id = 'miniMap_' + miniMapNum;
            canvas.setAttribute('id', id);
            canvas.style.width = width;
            canvas.style.height = mapHeight;
            canvas.style.margin = "0px auto";
            this.appendChild(canvas);

            var map = new BMap.Map(id, {
                mapType: mapType
            });
            map.enableScrollWheelZoom();
            map.centerAndZoom(new BMap.Point(miniCenterY, miniCenterX), miniZoom);
            var mini = new BMap.Polygon(miniCoords, {
                strokeColor: '#FF0000',
                strokeOpacity: 0.8,
                strokeWeight: 2,
                fillColor: '#0000FF',
                fillOpacity: 0.6
            });
            map.addOverlay(mini);
        }
    });
}

function getMapType(maptype) {
    if (typeof maptype !== 'string') {
        return BMAP_NORMAL_MAP;
    }
    switch (maptype.toLowerCase()) {
        case 'roadmap': return BMAP_NORMAL_MAP;
        case 'satellite': return BMAP_SATELLITE_MAP;
        case 'hybrid': return BMAP_HYBRID_MAP;
        case 'terrain': return BMAP_PERSPECTIVE_MAP;
        default: return BMAP_NORMAL_MAP;
    }
}

function userLocation(elem, width, height) {
    var num = 0;
    $("." + elem).css({ "font-size": "0px" });

    $("." + elem).each(function () {
        num += 1;

        var tag = $(this).context.tagName.toLowerCase();
        var data = $(this).text() ? $(this).text() : $(this).val();
        var zoom = 5;
        var center = new BMap.Point(54.333531, 23.907173);
        var point = null;
        var options = {};
        var draggable = true;
        var canvas = document.createElement('div');
        var textarea;
        var id = "userLocation_" + num;
        var mapType = getMapType($(this).attr('maptype'));
        var mapHeight = $(this).attr('hmap');
        if (mapHeight)
            mapHeight += 'px';
        else
            mapHeight = height;

        canvas.setAttribute("id", id);
        canvas.style.width = width;
        canvas.style.height = mapHeight;
        canvas.style.margin = "0px auto";

        if (tag !== "textarea") {
            options = { draggable: false, zoomControl: false, scrollwheel: false, disableDoubleClickZoom: true, disableDefaultUI: true };
            draggable = false;
            $(this).text("");
            this.appendChild(canvas);
        } else {
            var container = document.createElement('div');
            container.setAttribute("class", elem);
            options = { draggable: true, zoomControl: true, scrollwheel: true, disableDoubleClickZoom: false, disableDefaultUI: false };
            draggable = true;
            textarea = this;
            textarea.setAttribute("class", "form-control hidden");
            textarea.parentNode.insertBefore(container, textarea);
            container.appendChild(textarea);
            container.appendChild(canvas);
        }

        options.mapType = mapType;
        var map = new BMap.Map(id, options);
        map.enableScrollWheelZoom();
        map.centerAndZoom(center, zoom);
        var marker = new BMap.Marker(point, {
            draggable: draggable
        });

        map.addListener('drag', function () {
            if (point != null && tag === "textarea") {
                textarea.innerHTML = '{"center_point":["' + map.getCenter().lat + '","' + map.getCenter().lng + '"], "zoom":"' + map.getZoom() + '", "cords":["' + marker.getPosition().lat + '","' + marker.getPosition().lng + '"]}';
            }
        });

        map.addListener('zoom_changed', function () {
            if (point != null && tag === "textarea") {
                textarea.innerHTML = '{"center_point":["' + map.getCenter().lat + '","' + map.getCenter().lng + '"], "zoom":"' + map.getZoom() + '", "cords":["' + marker.getPosition().lat + '","' + marker.getPosition().lng + '"]}';
            }
        });

        marker.addListener('drag', function () {
            if (point != null && tag === "textarea") {
                textarea.innerHTML = '{"center_point":["' + map.getCenter().lat + '","' + map.getCenter().lng + '"], "zoom":"' + map.getZoom() + '", "cords":["' + marker.getPosition().lat + '","' + marker.getPosition().lng + '"]}';
            }
        });

        map.addListener('click', function (e) {
            if (tag === "textarea") {
                point = e.point;
                marker.setPosition(point);
                textarea.innerHTML = '{"center_point":["' + map.getCenter().lat + '","' + map.getCenter().lng + '"], "zoom":"' + map.getZoom() + '", "cords":["' + marker.getPosition().lat + '","' + marker.getPosition().lng + '"]}';
            }
        });

        if (data) {
            data = JSON.parse(data);
            zoom = Number(data.zoom);
            center = { lat: Number(data.center_point[0]), lng: Number(data.center_point[1]) };
            point = { lat: Number(data.cords[0]), lng: Number(data.cords[1]) };

            marker.setPosition(point);

            map.setZoom(zoom);
            map.setCenter(center);
            map.addOverlay(marker);
        }
    });
}
