#Similar Makefile which this format was inspired by: https://github.com/scities-data/metro-atlas_2014/blob/master/Makefile
# To a lesser extent, this guide https://github.com/datamade/data-making-guidelines and
# also Mike Bostock's article: https://bost.ocks.org/mike/make/

# := assignment only gets run once at the beginning of everything
# = assignment gets run each time (but can cause an infinite loop)

.DEFAULT_GOAL := all

all: data/geojson/prisons-swing-districts.json

# via MIT elections
data/csv/1976-2018-house.csv:
	mkdir -p $(dir $@)
	curl 'https://dataverse.harvard.edu/api/access/datafile/3417583?format=original&gbrecs=true' -o $@.download
	mv $@.download $@


data/geojson/detention_facilities.json:
	mkdir -p $(dir $@)
	echo save the final GeoJSON file from the left panel in https://observablehq.com/d/c472ec00bc257a08	
	touch $@

data/geojson/116th_congress.geojson:
	mkdir -p $(dir $@)
	curl 'https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_116th_Congressional_Districts/FeatureServer/0/query?where=1=1&outFields=*&returnGeometry=true&f=pgeojson' -o $@.download
	mv $@.download $@

data/geojson/prisons-swing-districts.json: data/geojson/116th_congress.geojson data/csv/1976-2018-house.csv data/geojson/detention_facilities.json 
	mkdir -p $(dir $@)
	mapshaper -i $< $(word 2,$^) combine-files \
	 -each "district=parseInt(CDFIPS,10), state_district=[parseInt(STFIPS,10),district].join('_')" target="116th_congress" \
$ 	 -each "state_district=[state_fips,district].join('_')" target="1976-2018-house" \
 	-filter "year===2018" target="1976-2018-house" \
	-join target=116th_congress  keys="state_district,state_district" source=1976-2018-house where="isMax(candidatevotes)" unjoined \
	-rename-fields "runnerUp=candidate,runnerUpVotes=candidatevotes,runnerUpParty=party" target="unjoined" \
	-join target=116th_congress keys="state_district,state_district" source=unjoined \
	-each "runnerUpDiff=candidatevotes-runnerUpVotes" \
	-join $(word 3,$^) source="detention_facilities" target="116th_congress" sum-fields="facilityPopulation" \
	-each "impactRatio=facilityPopulation/(runnerUpDiff+1)" \
	-filter "STATE_ABBR!=='DC'" target=116th_congress