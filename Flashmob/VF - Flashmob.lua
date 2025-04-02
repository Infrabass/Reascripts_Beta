-- @ReaScript Name Flashmob
-- @Screenshot https://imgur.com/i0Azzz1
-- @Author Vincent Fliniaux (Infrabass)
-- @Links https://github.com/Infrabass/Reascripts_Beta
-- @Version 0.2.2
-- @Changelog
--   Beta release
-- @Provides
--   [main] VF - Flashmob.lua
--   Flashmob.RfxChain
--   vf_FLASHMOB.jsfx
--   vf_FLASHMOB_GEN.jsfx
--   [effect] vf_FLASHMOB.jsfx
--   [effect] vf_FLASHMOB_GEN.jsfx
-- @About 
--   # Powerful modulation system for Reaper based on the mighty Snap Heap from Kilohearts
--   
--   ## Dependencies
--   - Requires ReaImGui


--[[
Full Changelog:	
	v0.1
		+ Beta release	
	v0.2
		+ Improve managing of missing dependencies
		+ Detect if Snap Heap is missing
		+ Add a subtle close button to close the window
	v0.2.1
		+ Improve missing Snap Heap detection
	v0.2.2
		+ Small fix

]]


------------------------------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------------------------------

local function Print(var) reaper.ShowConsoleMsg(tostring(var) .. "\n") end
local function Msg(str, var) reaper.ShowConsoleMsg(str..": "..tostring(var) .. "\n") end
local function Esc(str) return str:gsub('[%(%)%+%-%[%]%.%^%$%*%?%%]','%%%0') end
local function Bool(var) if var == 1 then return true else return false end end
local function Command(var) reaper.Main_OnCommandEx(tostring(var), 0, 0) end
local function CommandEx(var) reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_" .. string.sub(var, 2)), 0, 0) end
local function TableAppend(table, var) table[#table+1] = var end
local function Unsel_item() Command(40289) end -- Item: Unselect all items
local function Unsel_track() Command(40297) end -- Track: Unselect all tracks
local function Time_sel_to_item() Command(40290) end -- Time selection: Set time selection to items
local function SaveCurPos()
	cur_pos = reaper.GetCursorPositionEx(0)
	reaper.SetExtState("Edit_Cursor_Position","Edit_Cursor_Position_KEY",cur_pos,0)
end
local function RestoreCurPos()
	cur_pos = reaper.GetExtState("Edit_Cursor_Position","Edit_Cursor_Position_KEY")
	reaper.SetEditCurPos2(0, cur_pos, 0, 0)
end
local function Save_track_sel()
	tool_sel_track_array = {}
	for i=0, reaper.CountSelectedTracks(0)-1 do tool_sel_track_array[#tool_sel_track_array+1] = reaper.GetTrackGUID(reaper.GetSelectedTrack(0, i)) end
end
local function Restore_track_sel()
	Unsel_track()
	for i=1, #tool_sel_track_array do
		local track = reaper.BR_GetMediaTrackByGUID(0, tool_sel_track_array[i])
		if track then reaper.SetTrackSelected(track, 1) end
	end
end
local function Save_item_sel()
	tool_sel_item_array = {}
	for i=0, reaper.CountSelectedMediaItems(0)-1 do tool_sel_item_array[#tool_sel_item_array+1] = reaper.BR_GetMediaItemGUID(reaper.GetSelectedMediaItem(0, i)) end
end
local function Restore_item_sel()
	Unsel_item()
	for i=1, #tool_sel_item_array do
		local item = reaper.BR_GetMediaItemByGUID(0, tool_sel_item_array[i])
		if item then reaper.SetMediaItemSelected(item, 1) end
	end
end

function toboolean(a)
	if a > 0 then a = true else a = false end
	return a
end

function CheckFloatEquality(a,b)
	return (math.abs(a-b)<0.00001)
end

function sort_func(a,b)
	if (a.pos == b.pos) then
		return a.track < b.track
	end
	if (a.pos < b.pos) then
		return true
	end
end

function CheckTableEquality(t1,t2) -- Re-ordering before comparing
	t1_string = {}
	t2_string = {}
	for i,n in ipairs(t1) do t1_string[i] = tostring(n) end
	for i,n in ipairs(t2) do t2_string[i] = tostring(n) end
	table.sort(t1_string)
	table.sort(t2_string)
	for i,v in next, t1_string do if t2_string[i]~=v then return false end end
	for i,v in next, t2_string do if t1_string[i]~=v then return false end end
	return true
end

function PrintWindowSize()
	w, h = reaper.ImGui_GetWindowSize( ctx )
	Print(w.."\n"..h)		
end

function ScaleValToNewRange(val, min_new_range, max_new_range, min_old_range, max_old_range)
	return (max_new_range - min_new_range) * (val - min_old_range) / (max_old_range - min_old_range) + min_new_range
end

function ColourToFloat(number)
	local number = number / 255
	return number
end  

function Round(num)
	return num % 1 >= 0.5 and math.ceil(num) or math.floor(num)
end  

function Brighten(val, inc)
	if not inc then inc = 0.2 end
	val = val + inc
	if val > 1 then val = 1 end
	return val
end

function Darken(val, inc)
	if not inc then inc = 0.3 end
	val = val - inc
	if val < 0 then val = 0 end
	return val
end

function SimplifyPluginNames(str)
	str = str:gsub(".-: ", "")
	str = str:gsub(" %(.-%)", "")
	str = str:gsub("(.*%/)(.*)", "%2")
	return str
end

function ReplaceRareUnicode(val)
	val = val:gsub('−', '-') -- Workaround to replace "minus" characters with dash (used by khs)
	val = val:gsub('\u{202F}', ' ') -- Workaround to replace "narrow non-breaking space" characters with space (used by khs)	
	return val
end	

function ClipText(str, width)
		if width <= 0 then width = 0 end
		local ellipsis = ".."
		
		-- If text fits, return as is
		if reaper.ImGui_CalcTextSize(ctx, str) <= width then
				return str
		end

		-- Gradually shorten the string until it fits
		while #str > 1 do
				str = str:sub(1, -2)  -- Remove last character
				if reaper.ImGui_CalcTextSize(ctx, str .. ellipsis) <= width then
						return str .. ellipsis
				end
		end
		return ellipsis  -- If nothing fits, return just ".."
end

function WrapText(str, width)
	if width < 0 then width = 0 end
	local words = {}
	for word in str:gmatch("%S+") do
		table.insert(words, word)
	end

	local wrappedText = ""
	local line = ""

	for _, word in ipairs(words) do
		local testLine = line == "" and word or line .. " " .. word
		local testSize = {reaper.ImGui_CalcTextSize(ctx, testLine)}

		if testSize[1] > width then
			wrappedText = wrappedText .. line .. "\n"
			line = word
		else
			line = testLine
		end
	end
	
	wrappedText = wrappedText .. line
	return wrappedText
end

function GetLabelMaxWidth()
		local max_label_width = reaper.ImGui_GetContentRegionAvail(ctx) - reaper.ImGui_CalcItemWidth(ctx)
		return max_label_width
end


------------------------------------------------------------------------------------
-- SECONDARY FUNCTIONS
------------------------------------------------------------------------------------

function GetFlashmobInstances(track, target_fx_name)
	local t_flashmob_id = {}	
	local flashmob_is_invalid
	local fx_count = reaper.TrackFX_GetCount(track)	

	for fx_id = 0, fx_count - 1 do
		local find_Flashmob
		local retval, fx_type = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "fx_type")
		if fx_type == "Container" then
			local first_subfx_id = 0x2000000 + ((0 + 1) * (fx_count + 1)) + (fx_id + 1) -- (index of FX in container + 1) * (fxchain count + 1) + (index of container + 1)		
			local retval, fx_name = reaper.TrackFX_GetFXName(track, first_subfx_id, "")
			if retval and fx_name:find(target_fx_name) then
				t_flashmob_id[#t_flashmob_id+1] = fx_id
				find_Flashmob = true
			end
			-- Check if FX inside Flashmob are offline
			if find_Flashmob then
				local _, container_fx_num = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "container_count")
				for j=0, container_fx_num-1 do
					local container_fx = 0x2000000 + ((j + 1) * (fx_count + 1)) + (fx_id + 1) -- (index of FX in container + 1) * (fxchain count + 1) + (index of container + 1)		
					if reaper.TrackFX_GetNumParams(track, container_fx) <= 3 then
						flashmob_is_invalid = true
					end
				end
			end
		end			
	end

	if t_flashmob_id[1] == nil or flashmob_is_invalid == true then
		return false, t_flashmob_id, flashmob_is_invalid  -- Not found or some FX are offline
	else
		return true, t_flashmob_id
	end
end

function CheckIfStoredInstanceExist(track, target_fx_name, index)
	local t_flashmob_id = {}	
	local fx_count = reaper.TrackFX_GetCount(track)	

	local retval, fx_type = reaper.TrackFX_GetNamedConfigParm(track, index, "fx_type")
	if fx_type == "Container" then
		local first_subfx_id = 0x2000000 + ((0 + 1) * (fx_count + 1)) + (index + 1) -- (index of FX in container + 1) * (fxchain count + 1) + (index of container + 1)		
		local retval, fx_name = reaper.TrackFX_GetFXName(track, first_subfx_id, "")
		if retval and fx_name:find(target_fx_name) then
			return true
		end
	end			
	return false
end

function GetLastTouchedFXParam(track)
	local result	
	local rv, track_id, itemidx, takeidx, fx, param = reaper.GetTouchedOrFocusedFX(0) -- Get last touched FX parameter		
	if rv == false then
		result = -1 -- INVALID: No parameter
	else
		if fx >= 16777216 then
			-- Print(fx)
			if fx >= 33554437 then
				result = -5 -- INVALID: FX is inside a FX container
			else
				result = -2 -- INVALID: Input FX
			end
		else		
			if itemidx > -1 then
				result = -3 -- INVALID: Take FX
			else
				if (track_id == -1 and track_id ~= reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) or (track_id ~= reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")-1) then -- If last touched fx param is NOT on selected track (support master track)
					result = -4 -- INVALID: parameter is not on selected track

				else -- If last touched fx param is on selected track (support master track)
					if itemidx == -1 and fx < 16777216 then -- If not take FX nor input FX...
						local new_param_guid_hack = ((track_id+4)*-66) * (fx+13) * ((param+39)*-73) + track_id -- Pseudo random gen number to check if last touched param changed (quicker than using the FX GUID)	
						if new_param_guid_hack ~= last_param_guid_hack then

							-- Bingo, a new parameter have been detected
							result = 1
						else

							-- The last-touched parameter is valid but isn't new
							result = 0
						end
					end
				end
			end
		end
	end

	if result < 0 then		
		t_last_param = {}	
		t_pm_data = {}
		t_pm_lfo = {}
		t_pm_acs = {}				
		last_param_guid_hack = nil				
		return false, result

	else
		local rv, fx_name_raw = reaper.TrackFX_GetFXName(track, fx)  
		local fx_name = SimplifyPluginNames(fx_name_raw)	
		local rv, param_name = reaper.TrackFX_GetParamName(track, fx, param)
		t_last_param = {          
			param = param,
			param_name = param_name,
			fx = fx,
			fx_name = fx_name,
			fx_name_raw = fx_name_raw
		}  

		GetPMData(track, fx, param) -- Get global parameter modulation and PLINK data
		GetNativeLFOData(track, fx, param) -- Get native LFO data
		GetNativeACSData(track, fx, param) -- Get native ACS data

		last_param_guid_hack = new_param_guid_hack		
		return true, result
	end
end

function GetPMData(track, fx, param)
	local _, mod_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".mod.active")	
	local _, baseline = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".mod.baseline")		

	local _, acs_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.active")

	local _, lfo_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.active") 	

	local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".plink.active") 
	local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".plink.effect") 
	local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".plink.param")			
	local _, link_scale = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".plink.scale")	

	local _, midi_learn = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".learn.midi1")	

	t_pm_data = {          
		mod_active = tonumber(mod_active),
		baseline = tonumber(baseline),
		acs_active = tonumber(acs_active),
		lfo_active = tonumber(lfo_active),
		link_active = tonumber(link_active),
		link_source_fx = tonumber(link_source_fx),
		link_source_param = tonumber(link_source_param),
		link_scale = tonumber(link_scale),
		midi_learn = tonumber(midi_learn)		
	}  
end

function GetNativeACSData(track, fx, param)
	local rv

	local _, acs_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.active")
	local _, acs_strength = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.strength")				
	local _, acs_dir = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.dir")	
	local _, acs_attack = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.attack")	
	local _, acs_release = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.release")
	local _, acs_chan = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan")	
	local _, acs_dblo = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.dblo")
	local _, acs_dbhi = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.dbhi")
	local _, acs_stereo = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".acs.stereo")

	if acs_active == "" then acs_active = 0 end
	if acs_release == "" then acs_release = 300 end
	if acs_attack == "" then acs_attack = 300 end
	if acs_strength == "" then acs_strength = 1 end
	if acs_dir == "" then acs_dir = 1 end
	if acs_chan == "" then acs_chan = 1 end
	if acs_dblo == "" then acs_dblo = -24 end
	if acs_dbhi == "" then acs_dbhi = 0 end
	if acs_stereo == "" then acs_stereo = 0 end

	-- Print("acs_stereo:")
	-- Print(acs_stereo)
	-- Print("acs_chan:")
	-- Print(acs_chan)	
	-- Print("acs_release:")
	-- Print(acs_release)	
	-- Print("acs_attack:")
	-- Print(acs_attack)	
	-- Print("acs_dir:")
	-- Print(acs_dir)	
	-- Print("acs_dblo:")
	-- Print(acs_dblo)	
	-- Print("acs_dbhi:")
	-- Print(acs_dbhi)							

	acs_active = tonumber(acs_active)
	acs_release = tonumber(acs_release)
	acs_attack = tonumber(acs_attack)
	acs_strength = tonumber(acs_strength)
	acs_dir = tonumber(acs_dir)
	acs_chan = tonumber(acs_chan)
	acs_dblo = tonumber(acs_dblo)
	acs_dbhi = tonumber(acs_dbhi)
	acs_stereo = tonumber(acs_stereo)

	t_acs_params = {
		acs_active = acs_active,
		acs_release = acs_release,
		acs_attack = acs_attack,
		acs_strength = acs_strength,
		acs_dir = acs_dir,
		acs_chan = acs_chan,
		acs_dblo = acs_dblo,
		acs_dbhi = acs_dbhi,
		acs_stereo = acs_stereo		
	}
end

function GetNativeLFOData(track, fx, param)
	local rv

	local _, lfo_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.active")
	local _, lfo_shape = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.shape")
	local _, lfo_speed = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed")
	local _, lfo_strength = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.strength")				
	local _, lfo_dir = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir")
	local _, lfo_phase = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.phase")	
	local _, lfo_temposync = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.temposync")
	local _, lfo_free = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. param .. ".lfo.free")

	-- Print("lfo_active:")
	-- Print(lfo_active)	
	-- Print("lfo_shape:")
	-- Print(lfo_shape)
	-- Print("lfo_speed:")
	-- Print(lfo_speed)
	-- Print("lfo_strength:")
	-- Print(lfo_strength)
	-- Print("lfo_dir:")
	-- Print(lfo_dir)
	-- Print("lfo_phase:")
	-- Print(lfo_phase)
	-- Print("lfo_temposync:")
	-- Print(lfo_temposync)
	-- Print("lfo_free:")
	-- Print(lfo_free)					

	if lfo_active == "" then lfo_active = 0 end
	if lfo_shape == "" then lfo_shape = 0 end
	if lfo_speed == "" then lfo_speed = 1 end
	if lfo_strength == "" then lfo_strength = 1 end
	if lfo_dir == "" then lfo_dir = 1 end
	if lfo_phase == "" then lfo_phase = 0 end
	if lfo_temposync == "" then lfo_temposync = 0 end
	if lfo_free == "" then lfo_free = 0 end	

	lfo_active = tonumber(lfo_active)
	lfo_shape = tonumber(lfo_shape)
	lfo_speed = tonumber(lfo_speed)
	lfo_strength = tonumber(lfo_strength)
	lfo_dir = tonumber(lfo_dir)
	lfo_phase = tonumber(lfo_phase)
	lfo_temposync = tonumber(lfo_temposync)
	lfo_free = tonumber(lfo_free)

	t_lfo_params = {
		lfo_active = lfo_active,
		lfo_shape = lfo_shape,
		lfo_speed = lfo_speed,
		lfo_strength = lfo_strength,
		lfo_dir = lfo_dir,
		lfo_phase = lfo_phase,
		lfo_temposync = lfo_temposync,
		lfo_free = lfo_free		
	}
end

function FindParamID(track, fx, param_name)
	for i=0, reaper.TrackFX_GetNumParams(track, fx)-1 do
		local _, actual_param_name = reaper.TrackFX_GetParamName(track, fx, i)
		if actual_param_name == param_name then
			return i
		end
	end

	return -1
end

function LinkParam(track, touched_fx, fx, touched_param, param, new_baseline, param_is_linked_to_anything, show_track_control)
	if param_is_linked_to_anything == 1 then	
		local user_input_overwrite = reaper.ShowMessageBox("The parameter is already mapped.\nAre you sure you want to overwrite the mapping?", "OVERWRITE MAPPING?", 4)
		if user_input_overwrite == 7 then -- NO
			return
		end
	end
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.effect", fx)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.param", param)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.active", 1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.offset", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.scale", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.active", 1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.baseline", new_baseline)

	if show_track_control == true then
		ShowInTrackControl(track, touched_fx, touched_param)
	end

	-- if param_lock == 1 then
		GetPMData(track, touched_fx, touched_param)
	-- end
end

function UnlinkParam(track, touched_fx, touched_param)
	local user_input_overwrite = reaper.ShowMessageBox("Are you sure you want to delete the mapping?", "DELETE MAPPING?", 4)
	if user_input_overwrite == 7 then -- NO
		return
	end	

	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.effect", -1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.param", -1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.active", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.offset", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.scale", 0)

	if t_pm_data.lfo_active == 0 and t_pm_data.acs_active == 0 then
		-- reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.active", 0)
		reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.baseline", 0)
		RemoveTrackControl(track, touched_fx, touched_param)
	end
end

function ShowInTrackControl(track, fx, param)
	for i=0, reaper.CountTCPFXParms(0, track)-1 do
		local retval, track_control_fx , track_control_param = reaper.GetTCPFXParm(0, track, i)
		if track_control_fx == fx and track_control_param == param then
			break
		end
	end
	reaper.SNM_AddTCPFXParm(track, fx, param)
end

function RemoveTrackControl(track, fx, param)
	for i=0, reaper.CountTCPFXParms(0, track)-1 do
		local retval, track_control_fx , track_control_param = reaper.GetTCPFXParm(0, track, i)
		if track_control_fx == fx and track_control_param == param then
			reaper.SNM_AddTCPFXParm(track, fx, param) -- Add to track control just to be sure the next action will hide it
			Command(41141) -- FX: Show/hide track control for last touched FX parameter
			break
		end
	end
end

function GetAssignations(track, fx, param)
	local t_assignations = {}
	for i=0, reaper.TrackFX_GetCount(track) -1 do
		local total_fx = reaper.TrackFX_GetCount(track)
		for j=0, reaper.TrackFX_GetNumParams(track, i) -1 do
			local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.active") 			
			local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.effect") 
			local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.param")
			link_active = tonumber(link_active)
			link_source_fx = tonumber(link_source_fx)
			link_source_param = tonumber(link_source_param)

			if link_active == 1 and link_source_fx == fx and link_source_param == param then
				local _, fx_name = reaper.TrackFX_GetFXName(track, i)
				fx_name = fx_name:gsub('——', '-') -- Workaround to replace "2 long dashes" characters with one small dash (used by Flashmob)
				fx_name = fx_name:gsub('—', '-') -- Workaround to replace "1 long dashes" characters with one small dash (used by Flashmob)
				fx_name = fx_name .. " (" .. i + 1 .. "/" .. total_fx .. ")"
				local _, param_name = reaper.TrackFX_GetParamName(track, i, j)
				t_assignations[#t_assignations+1] = {fx_id = i, param_id = j, fx_name = fx_name, param_name = param_name}
			end
		end
	end
	return t_assignations
end

function ToggleNativeLFO(track, fx, param, state)
	reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.active", state)						

	-- Logic for param value/baseline when activating or de-activating LFO
	local new_baseline
	if (t_pm_data.link_active == 1 and t_pm_data.link_source_param > 7) or t_pm_data.acs_active == 1 then
		new_baseline = t_pm_data.baseline
	else							
		if state == 1 then
			new_baseline = reaper.TrackFX_GetParam(track, fx, param)
			ShowInTrackControl(track, fx, param) -- Show in Track control					
		else
			new_baseline = 0
			reaper.TrackFX_SetParam(track, fx, param, t_pm_data.baseline)
			RemoveTrackControl(track, fx, param) -- Remove from Track control
		end
	end	

	if state == 1 then
		-- Set custom default values if native default values are detected
		if t_lfo_params.lfo_active == 0 and t_lfo_params.lfo_shape == 0 and t_lfo_params.lfo_speed == 1 and t_lfo_params.lfo_strength == 1 and t_lfo_params.lfo_dir == 1 and t_lfo_params.lfo_phase == 0 and t_lfo_params.lfo_temposync == 0 and t_lfo_params.lfo_free == 0 then
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.strength", 0.25)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir", 0)
		end
	end

	reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".mod.baseline", new_baseline)
	GetPMData(track, fx, param)
end

function ToggleNativeACS(track, fx, param, state)
	reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.active", state)			

	-- Logic for param value/baseline when activating or de-activating ACS
	local new_baseline
	if (t_pm_data.link_active == 1 and t_pm_data.link_source_param > 7) or t_pm_data.lfo_active == 1 then
		new_baseline = t_pm_data.baseline
	else				
		if state == 1 then
			new_baseline = reaper.TrackFX_GetParam(track, fx, param)
			ShowInTrackControl(track, fx, param) -- Show in Track control

		else
			new_baseline = 0
			reaper.TrackFX_SetParam(track, fx, param, t_pm_data.baseline)
			RemoveTrackControl(track, fx, param) -- Remove from Track control
		end
	end	

	if state == 1 then
		-- Set custom default values if native default values are detected
		if t_acs_params.acs_active == 0 and t_acs_params.acs_attack == 300 and t_acs_params.acs_release == 300 and t_acs_params.acs_strength == 1 and t_acs_params.acs_dir == 1 and t_acs_params.acs_dblo == -24 and t_acs_params.acs_dbhi == 0 and t_acs_params.acs_chan == 1 and t_acs_params.acs_stereo == 0 then
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dblo", -30)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 0)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.stereo", 1)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.attack", 150)
		end
	end	

	reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".mod.baseline", new_baseline)			
	GetPMData(track, fx, param)
end

-- function ModChild(track, fx, index, touched_fx, touched_param, track_sel_changed, param_is_linked_to_anything)
-- 	local str_index = tostring(index)
function ModGraphData(track, fx, index)
	local str_index = tostring(index)
	local mod_param_id = index + 7
	local mod_val = reaper.TrackFX_GetParamEx(track, fx, mod_param_id)	



	local PLOT_SIZE = 90

	-- The big challenge here have been to be able to assign dynamic variable name. It's possible with the global table "_G"
	if not _G["plots" .. str_index] or track_sel_changed == true or reset_plot_lines == true then
		_G["plots" .. str_index] = {
			offset       = 1,
			data         = reaper.new_array(PLOT_SIZE),
		}
		_G["plots" .. str_index].data.clear()
		reset_plot_lines = nil
	end		

	_G["plots" .. str_index].data[_G["plots" .. str_index].offset] = mod_val
	_G["plots" .. str_index].offset = (_G["plots" .. str_index].offset % PLOT_SIZE) + 1				
end



------------------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------------------

function ToolTip(text)
	if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal() | reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
		reaper.ImGui_PushFont(ctx, fonts.medium)
		reaper.ImGui_BeginTooltip(ctx)
		-- reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
		reaper.ImGui_Text(ctx, text)		
		-- reaper.ImGui_PopTextWrapPos(ctx)
		reaper.ImGui_EndTooltip(ctx)
		reaper.ImGui_PopFont(ctx)
	end
end

function ToolTipPlotLines(text)
	if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
		reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
		reaper.ImGui_SetTooltip(ctx, text)
		reaper.ImGui_PopTextWrapPos(ctx)
	end
end

function ColorPalette()
	local col_1 = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(65), ColourToFloat(176), ColourToFloat(246), 0.9)
	local col_2 = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(116), ColourToFloat(251), ColourToFloat(234), 0.75)
	local col_3 = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(137), ColourToFloat(249), ColourToFloat(79), 0.75)
	local col_4 = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(254), ColourToFloat(208), ColourToFloat(103), 0.8)
	local col_5 = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(255), ColourToFloat(105), ColourToFloat(105), 0.9)
	local col_6 = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(205), ColourToFloat(142), ColourToFloat(255), 0.9)	
	local t_color_palette = {col_1, col_2, col_3, col_4, col_5, col_6, col_1, col_2, col_3, col_4, col_5, col_6}
	return t_color_palette
end

function SetTheme()
	-- local col_text, col_win_bg, col_popup_bg, col_button, col_button_hovered, col_button_active
	-- col_text = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1)
	-- col_win_bg = reaper.ImGui_ColorConvertDouble4ToU32(0.15, 0.15, 0.15, 1)
	-- col_popup_bg = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.7)
	-- col_button = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.6)
	-- col_button_hovered = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.8)
	-- col_button_active = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.8)

	local idle_alpha = 0.6
	local active_alpha = 0.2
	local hovered_alpha = 0

	local bg_idle_alpha = 0.8
	local bg_active_alpha = 0.5
	local bg_hovered_alpha = 0.45

	-- Tab
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), DarkerColor2(UI_color, idle_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabSelected(), DarkerColor2(UI_color, active_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), DarkerColor2(UI_color, hovered_alpha))

	-- Header
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), DarkerColor2(UI_color, idle_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), DarkerColor2(UI_color, active_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), DarkerColor2(UI_color, hovered_alpha))	

	-- Button
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor2(UI_color, idle_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), DarkerColor2(UI_color, active_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), DarkerColor2(UI_color, hovered_alpha))		

	-- BG
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), DarkerColor2(UI_color, bg_idle_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), DarkerColor2(UI_color, bg_active_alpha))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), DarkerColor2(UI_color, bg_hovered_alpha))		

	-- Checkbox & Radio
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), DarkerColor2(UI_color, hovered_alpha))
end

function ToggleButton(ctx, label, selected, size_w, size_h)
	if selected == 1 then
		local col_active = reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_ButtonActive())
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), col_active)
	end
	local toggled = reaper.ImGui_Button(ctx, label, size_w, size_h)
	if selected == 1 then reaper.ImGui_PopStyleColor(ctx) end
	if toggled then
		if selected == 1 then
			selected = 0
		else
			selected = 1
		end
	end
	return toggled, selected
end

function GetTrackColor(target_track)
	local track_color = reaper.ImGui_ColorConvertNative(reaper.GetTrackColor(target_track))
	track_color = (track_color << 8) | 0xFF -- Add alpha value (thanks Cfillion)
	local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(track_color) -- Poor twist to give more contrast with black text
	if r == 0 and g == 0 and b == 0 then
		track_color = reaper.ImGui_ColorConvertDouble4ToU32(0.65, 0.65, 0.65, 1)
	else   
		r = Brighten(r)
		g = Brighten(g)
		b = Brighten(b)
		track_color = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)
	end
	return track_color
end

function DarkerColor(color, mode)

	local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(color)
	if color == -1499027713 then
		a = a - 0.5 -- If track has no color, make it a bit darker
		if mode == 1 then
			a = a - 0.3
		end
		if mode == 3 then
			a = a + 0.2
		end		
	else
		a = Darken(a)
		if mode == 1 then
			a = a - 0.5
		end
		if mode == 2 then
			a = a - 0.3
		end
		if mode == 3 then
			a = a - 0.1
		end	
		if mode == 4 then
			a = a + 0.1
		end					
	end
	if a < 0.1 then a = 0.1 end		

	color = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)		
	return color
end

function DarkerColor2(color, val)
	local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(color)
	a = Darken(a, val)
	color = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)	
	return color
end

function BrighterColor(color, mode)
	local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(color)
	if color == -1499027713 then
		r, g, b, a = 1, 1, 1, 0.55
		-- track_color = reaper.ImGui_ColorConvertDouble4ToU32(0.85, 0.85, 0.85, 1)
	end

	a = Brighten(a)
	if mode == 1 then
		a = a + 0.5
	end
	if mode == 2 then
		a = a - 0.2
	end	
	if mode == 2 then
		a = a - 0.1
	end		
	if a > 1 then a = 1 end	

	color = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)	
	return color
end

function BrighterColor2(color, val)
	local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(color)
	a = Brighten(a, val)
	color = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)	
	return color
end

function GetBrightness(color)
	local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(color)
	return (r + g + b) / 3
end

function CustomSlider(label, valueA, valueB, min, max, width, height, default, mod_indicator, active, active_mod_range, color)
	local width = width or 100
	local height = height or 12
	if width < 1 then width = 1 end
	if height < 1 then height = 1 end

	if valueB < min then valueB = min end
	if valueB > max then valueB = max end

	local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
	
	-- Calculate position
	local cursor_pos = {reaper.ImGui_GetCursorScreenPos(ctx)}
	local x, y = cursor_pos[1], cursor_pos[2]
	
	-- Calculate normalized values
	local range = max - min
	local normalizedA = (valueA - min) / range
	local normalizedB = (valueB - min) / range
	
	-- Colors
	local bg_color
	if active == 1 then  
	-- 	if label == "Value" then
	-- 		bg_color = DarkerColor(color, 1)
	-- 	else	
	-- 		bg_color = DarkerColor(color, 2)
	-- 	end
		bg_color = DarkerColor(color, 1)
	else
		bg_color = DarkerColor(DarkerColor(color, 1))
	end

	local frame_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1.0)
	local center_color
	if active == 1 then
		center_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.6)
	else
		center_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.3)
	end
	local indicator_a_color
	if active == 1 then    
		indicator_a_color = color
	else
		indicator_a_color = DarkerColor(color)
	end
	local indicator_b_color = reaper.ImGui_ColorConvertDouble4ToU32(0.8, 0.1, 0.1, 1.0)
	local text_color = reaper.ImGui_ColorConvertDouble4ToU32(1.0, 1.0, 1.0, 1.0)
	
	-- Draw background
	reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, bg_color)
	
	-- Draw indicator lines
	local indicator_width = 2
	-- local indicator_width_mod = 2
	local indicator_a_x = x + (width * normalizedA)
	local indicator_b_x = x + (width * normalizedB)
	local indicator_center = x + width * 0.5  
	
	-- Draw center (grey)
	reaper.ImGui_DrawList_AddRectFilled(
		draw_list,
		indicator_center - indicator_width/3,
		y + height - 1,
		indicator_center + indicator_width/3,
		y + height - 4,
		center_color
	)    

	-- Draw indicator B (red) if applicable
	-- if active_mod_range == 1 and mod_indicator == true then
	-- 	reaper.ImGui_DrawList_AddRectFilled(
	-- 		draw_list,
	-- 		indicator_b_x - indicator_width_mod/2,
	-- 		y,
	-- 		indicator_b_x + indicator_width_mod/2,
	-- 		y + height,
	-- 		indicator_b_color
	-- 	)  
	-- end  

		-- Draw range from valueA to valueB using a brighter color
	if active_mod_range == 1 and mod_indicator == true then		
		local indicator_a_x = x + (width * normalizedA)
		local indicator_b_x = x + (width * normalizedB)
		local range_left = math.min(indicator_a_x, indicator_b_x)
		local range_right = math.max(indicator_a_x, indicator_b_x)
		-- Assuming BrighterColor increases brightness; adjust factor as needed (0.5 here)
		-- local range_color = BrighterColor(color, 1)
		local range_color = DarkerColor(color, 2)
		reaper.ImGui_DrawList_AddRectFilled(draw_list, range_left, y, range_right, y + height, range_color)	
	end

	-- Draw indicator A (blue)
	reaper.ImGui_DrawList_AddRectFilled(
		draw_list,
		indicator_a_x - indicator_width * 0.5,
		y,
		indicator_a_x + indicator_width * 0.5,
		y + height,
		indicator_a_color
	)
	
	reaper.ImGui_InvisibleButton(ctx, label, width, height)
	
	-- Handle mouse interaction for the blue indicator (valueA)
	local is_hovered = reaper.ImGui_IsItemHovered(ctx)
	local is_active = reaper.ImGui_IsItemActive(ctx)
	local value_changed = false  

	if active == 1 then
		if is_active then
			-- Get the horizontal mouse delta (relative movement)
			local dx, _ = reaper.ImGui_GetMouseDelta(ctx)
			
			-- Check if Shift is held for fine-tuning
			local sensitivity
			if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
				sensitivity = 0.1
			else
				sensitivity = 1
			end
			
			-- Calculate new value increment based on relative mouse movement
			local delta_value = dx * (sensitivity * range / width)
			local new_value_a = valueA + delta_value
			
			-- Clamp value between min and max
			if new_value_a < min then new_value_a = min end
			if new_value_a > max then new_value_a = max end

			if valueA ~= new_value_a then
				valueA = new_value_a
				-- value_changed = true
			end
			value_changed = true
		end

		-- Reset to default on double-click
		if is_hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) then
			valueA = default
			value_changed = true
		end
	end
	
	return value_changed, valueA, valueB  
end


function ModChild(track, fx, index, touched_fx, touched_param, track_sel_changed, param_is_linked_to_anything)
	local str_index = tostring(index)
	-- local mod_param_id = FindParamID(track, fx, "Reaktor 6 FX: MOD " .. str_index)
	local mod_param_id = index + 7
	local mod_val = reaper.TrackFX_GetParamEx(track, fx, mod_param_id)
	-- local mod1_val_rounded = string.format("%.3f", mod1_val)

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), t_color_palette[index])	
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), t_color_palette[index])
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), DarkerColor(t_color_palette[index]))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), t_color_palette[index])	
	local visible = reaper.ImGui_BeginChild(ctx, 'Mod_Child' .. str_index, 0, 76, reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then

		-- MAP button		
		-- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), t_color_palette[index])
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), BrighterColor(t_color_palette[index]))
		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		if reaper.ImGui_Button(ctx, "MOD\n   " .. index, 40, 60) then
			if t_last_param.param then	

				-- Keep parameter current value if no native modulation is active
				local new_baseline
				if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
					new_baseline = t_pm_data.baseline
				else				
					new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
				end
				LinkParam(track, touched_fx, fx, touched_param, mod_param_id, new_baseline, param_is_linked_to_anything, true)
			else
				reaper.ShowMessageBox("\nYou must adjust a FX parameter before mapping to this modulator", "MAPPING FAILED", 0)
			end
		end	
		reaper.ImGui_PopFont(ctx)				

		if param_is_linked_to_anything == 1 then			
			ToolTip("Remap to MOD " .. index)	
		else
			ToolTip("Map to MOD " .. index)
		end
		reaper.ImGui_PopStyleColor(ctx, 1)
		reaper.ImGui_SameLine(ctx)

		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
		local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
		reaper.ImGui_DrawList_AddLine(draw_list, x - 2, y - win_padding_y, x - 2, y + 76, t_color_palette[index], thicknessIn)
		reaper.ImGui_SameLine(ctx)
		reaper.ImGui_Dummy(ctx, 4, 0)
		reaper.ImGui_SameLine(ctx)

		-- -- Graph
		-- local PLOT_SIZE = 90
		
		-- -- The big challenge here have been to be able to assign dynamic variable name. It's possible with the global table "_G"
		-- if not _G["plots" .. str_index] or track_sel_changed == true or reset_plot_lines == true then
		-- 	_G["plots" .. str_index] = {
		-- 		offset       = 1,
		-- 		data         = reaper.new_array(PLOT_SIZE),
		-- 	}
		-- 	_G["plots" .. str_index].data.clear()
		-- 	reset_plot_lines = nil
		-- end		

		-- _G["plots" .. str_index].data[_G["plots" .. str_index].offset] = mod_val
		-- _G["plots" .. str_index].offset = (_G["plots" .. str_index].offset % PLOT_SIZE) + 1				

		local x, y = reaper.ImGui_GetCursorPos(ctx)
		local width, height = reaper.ImGui_GetWindowSize(ctx) 
		reaper.ImGui_SetNextItemWidth(ctx, width - x - win_padding_x)
		reaper.ImGui_PlotLines(ctx, '##Lines' .. str_index, _G["plots" .. str_index].data, _G["plots" .. str_index].offset - 1, overlay, 0, 1.0, 0, 60.0)
		local data_str = tostring(mod_val)		
		data_str = string.format("%.2f", data_str)
		ToolTipPlotLines(data_str) -- Override the default plotlines tooltip (that have a instantaneous hard-coded tooltip)
		ToolTip("Left-click: Open Snapheap\nRight-click: Show assignations")

		-- Open Snap Heap
		if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
			-- The following function TrackFX_Show() is working with an index of FX in container based-1 instead of based-0
			local offset = 1
			if index >= 3 and index <= 4 then offset = 2 end
			if index >= 5 and index <= 6 then offset = 3 end
			local fxCount = reaper.TrackFX_GetCount(track)

			local snapheap_index = 0x2000000 + ((offset + 1) * (fxCount + 1)) + (fx + 1) -- (index of FX in container + 1) * (fxchain count + 1) + (index of container + 1)

			-- Close all other Snap Heap FX windows
			for i=1, 3 do
				local snapheap_index_current = 0x2000000 + ((i + 1) * (fxCount + 1)) + (fx + 1)
				if snapheap_index ~= snapheap_index_current then
					reaper.TrackFX_Show(track, snapheap_index_current, 2)
				end
			end
			
			local open = reaper.TrackFX_GetOpen(track, snapheap_index)
			if open == true then
				reaper.TrackFX_Show(track, snapheap_index, 2)
			else
				reaper.TrackFX_Show(track, snapheap_index, 3)
				-- reaper.SetCursorContext(1)
			end
		end

		-- Modulator assignations popup
		if reaper.ImGui_BeginPopupContextItem(ctx, 'mod_popup') then
			local popup_width, popup_height = reaper.ImGui_GetWindowSize(ctx)
			local x, y = reaper.ImGui_GetCursorPos( ctx )
			reaper.ImGui_SetCursorPos(ctx, (popup_width * 0.5) - (width * 0.5), y)
			reaper.ImGui_PushFont(ctx, fonts.medium_bold)
			if reaper.ImGui_Button(ctx, "MOD " .. index, width) then
				-- reaper.TrackFX_SetParam(track, fx, macro_param_id, macro_val) -- To set as last touched param
				-- Command(41145) -- FX: Set alias for last touched FX parameter
			end		
			reaper.ImGui_PopFont(ctx)	
			-- ToolTip("Click to rename Macro")

			-- if slower_defer_update then
				t_assignations = GetAssignations(track, fx, mod_param_id) -- Need to optimize this potentially intense function
			-- end
			for i=1, #t_assignations do

				-- Use a dummy invisible button to detect hover first
				assignation_color = DarkerColor(t_color_palette[index], 4)
				local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].param_name)
				local x, y = reaper.ImGui_GetCursorPos( ctx )
				reaper.ImGui_InvisibleButton(ctx, "hover_area", text_size_x, text_size_y)
				ToolTip("Alt-click: Delete assignation")

				if reaper.ImGui_IsItemHovered(ctx) then
					assignation_color = BrighterColor(t_color_palette[index], 1)
				end

				-- Set as last touched parameter
				if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
				end		

				-- Delete modulation
				if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then																				
					local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
					UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
				end				

				-- Draw the text with the determined color
				reaper.ImGui_SameLine(ctx)
				reaper.ImGui_SetCursorPos(ctx, x, y)
				reaper.ImGui_SetItemAllowOverlap(ctx)
				reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].param_name)

				reaper.ImGui_SameLine(ctx)
				reaper.ImGui_Text(ctx, t_assignations[i].fx_name)
			end

			if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
				reaper.ImGui_CloseCurrentPopup(ctx)
			end

			reaper.ImGui_EndPopup(ctx)
		end		
		reaper.ImGui_OpenPopupOnItemClick(ctx, 'mod_popup', reaper.ImGui_PopupFlags_MouseButtonRight())				
	
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx, 4)
	reaper.ImGui_PopStyleVar(ctx)
end

function Macro(track, fx, index, touched_fx, touched_param, track_sel_changed, param_is_linked_to_anything)
	-- local UI_color = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Button())
	local str_index = tostring(index)

	local macro_param_id = index - 1 -- (0-based)
	local macro_val, min, max = reaper.TrackFX_GetParamEx(track, fx, macro_param_id)
	local _, macro_name = reaper.TrackFX_GetParamName(track, fx, macro_param_id)

	local macro_is_linked = 0
	local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. macro_param_id .. ".plink.active") 
	local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. macro_param_id .. ".plink.effect")
	local _, lfo_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. macro_param_id .. ".lfo.active")
	local _, acs_active = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. macro_param_id .. ".acs.active")
	local _, baseline = reaper.TrackFX_GetNamedConfigParm(track, fx, "param." .. macro_param_id .. ".mod.baseline")	
	link_active = tonumber(link_active) 
	link_source_fx = tonumber(link_source_fx)
	lfo_active = tonumber(lfo_active)	
	if lfo_active == nil then lfo_active = 0 end	
	acs_active = tonumber(acs_active)
	if acs_active == nil then acs_active = 0 end		
	baseline = tonumber(baseline)


	if link_active == 1 and link_source_fx == fx then -- if the macro is linked to a Flashmob container parameter...
		macro_is_linked = 1
	end		

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	-- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), t_color_palette[mod_container_table_id])
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor(t_color_palette[mod_container_table_id], 3))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), DarkerColor(t_color_palette[mod_container_table_id]))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), t_color_palette[mod_container_table_id])
	local visible = reaper.ImGui_BeginChild(ctx, 'Macro_Child' .. str_index, 0, 40 + win_padding_y * 2, reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then

		local x, y = reaper.ImGui_GetCursorPos(ctx)
		local width, height = reaper.ImGui_GetWindowSize(ctx) 
		local rv, macro_name = reaper.TrackFX_GetParamName(track, fx, macro_param_id)		
		local macro_name_clipped = ClipText(macro_name, width - x - win_padding_x - 6)		
		-- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor(UI_color))
		-- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), BrighterColor(UI_color, 2))
		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		if reaper.ImGui_Button(ctx, macro_name_clipped, width - x - win_padding_x, 18) then		
			if t_last_param.param and (touched_fx + t_last_param.param) ~= (fx + macro_param_id) then -- Check if last touched param is not the macro itself

				-- Keep parameter current value if no native modulation is active
				local new_baseline
				if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
					new_baseline = t_pm_data.baseline
				else				
					new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
				end
				LinkParam(track, touched_fx, fx, touched_param, macro_param_id, new_baseline, param_is_linked_to_anything, false)
			else
				reaper.ShowMessageBox("You must adjust a FX parameter before mapping to this modulator", "MAPPING FAILED", 0)
			end
		end
		reaper.ImGui_PopFont(ctx)
		-- reaper.ImGui_PopStyleColor(ctx, 2)

		-- Macro assignations popup
		if reaper.ImGui_BeginPopupContextItem(ctx, 'macro_popup') then
			local popup_width, popup_height = reaper.ImGui_GetWindowSize(ctx)
			local x, y = reaper.ImGui_GetCursorPos( ctx )
			reaper.ImGui_SetCursorPos(ctx, (popup_width * 0.5) - (width * 0.5), y)
			reaper.ImGui_PushFont(ctx, fonts.medium_bold)
			if reaper.ImGui_Button(ctx, macro_name, width) then
				reaper.TrackFX_SetParam(track, fx, macro_param_id, macro_val) -- To set as last touched param
				Command(41145) -- FX: Set alias for last touched FX parameter
			end			
			reaper.ImGui_PopFont(ctx)
			ToolTip("Click to rename Macro")

			-- if proj_updated then
				t_assignations = GetAssignations(track, fx, macro_param_id) -- Need to optimize this potentially intense function
			-- end
			for i=1, #t_assignations do

				-- Use a dummy invisible button to detect hover first
				-- if track_color == -1499027713 then -- Grey
				-- 	assignation_color = track_color
				-- else
				-- 	assignation_color = DarkerColor(track_color)
				-- end
				assignation_color = DarkerColor(t_color_palette[mod_container_table_id], 4)

				local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].param_name)
				local x, y = reaper.ImGui_GetCursorPos( ctx )
				reaper.ImGui_InvisibleButton(ctx, "hover_area", text_size_x, text_size_y)
				ToolTip("Alt-click: Delete assignation")

				if reaper.ImGui_IsItemHovered(ctx) then
					-- if track_color == -1499027713 then -- Grey
					-- 	assignation_color = BrighterColor(track_color)
					-- else
					-- 	assignation_color = track_color
					-- end
					assignation_color = BrighterColor(t_color_palette[mod_container_table_id])
				end

				-- Set as last touched parameter
				if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
				end	

				-- Delete modulation
				if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then																				
					local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
					UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
				end								

				-- Draw the text with the determined color
				reaper.ImGui_SameLine(ctx)
				reaper.ImGui_SetCursorPos(ctx, x, y)
				reaper.ImGui_SetItemAllowOverlap(ctx)
				reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].param_name)

				reaper.ImGui_SameLine(ctx)
				reaper.ImGui_Text(ctx, t_assignations[i].fx_name)
			end

			if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
				reaper.ImGui_CloseCurrentPopup(ctx)
			end			

			reaper.ImGui_EndPopup(ctx)
		end		
		reaper.ImGui_OpenPopupOnItemClick(ctx, 'macro_popup', reaper.ImGui_PopupFlags_MouseButtonRight())				
		-- reaper.ImGui_PopStyleColor(ctx, 2)

		if t_last_param.param then
			if (touched_fx + t_last_param.param) ~= (fx + macro_param_id) then -- Check if last touched param is not the macro itself
				if param_is_linked_to_anything == 1 then
					ToolTip("Left-click: Remap to MACRO " .. index .. "\n\nRight-click: Show Assignations")	
				else
					ToolTip("Left-click: Map to MACRO " .. index .. "\n\nRight-click: Show Assignations")
				end	
			else
				if param_is_linked_to_anything == 1 then
					ToolTip("Right-click: Show Assignations")	
				else
					ToolTip("Right-click: Show Assignations")
				end	
			end			
		end	

		reaper.ImGui_Dummy(ctx, 0, 0)

		local view_mod_range_slider = math.max(macro_is_linked, lfo_active, acs_active) -- Check if any modulation is active on the macro itself
		if view_mod_range_slider == 1 then
			_G["macro_baseline" .. str_index] = baseline
			_G["macro" .. str_index] = macro_val
			-- _G["rv_macro" .. str_index], _G["macro_baseline" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro_baseline" .. str_index], _G["macro" .. str_index], min, max, width - x - win_padding_x, 13, 50, true, 1, view_mod_range_slider, BrighterColor(UI_color, 1))
			_G["rv_macro" .. str_index], _G["macro_baseline" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro_baseline" .. str_index], _G["macro" .. str_index], min, max, width - x - win_padding_x, 13, 50, true, 1, view_mod_range_slider, BrighterColor(t_color_palette[mod_container_table_id], 3))
			if _G["rv_macro" .. str_index] == true then
				reaper.TrackFX_SetParam(track, fx, macro_param_id, _G["macro" .. str_index]) -- Set as last touched param
				if param_lock == 0 then
					GetLastTouchedFXParam(track)
					GetPMData(track, t_last_param.fx, t_last_param.param) -- Update data because macro values are displayed in the FX PARAMETER header
				end

				reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. macro_param_id .. ".mod.baseline", _G["macro_baseline" .. str_index])								
			end			
		else
			_G["macro" .. str_index] = macro_val
			-- _G["rv_macro" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro" .. str_index], 0, min, max, width - x - win_padding_x, 13, 50, false, 1, 0, BrighterColor(UI_color, 1))
			_G["rv_macro" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro" .. str_index], 0, min, max, width - x - win_padding_x, 13, 50, false, 1, 0, BrighterColor(t_color_palette[mod_container_table_id], 3))
			if _G["rv_macro" .. str_index] == true then
				reaper.TrackFX_SetParam(track, fx, macro_param_id, _G["macro" .. str_index])
			end			
		end
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx, 4)
	reaper.ImGui_PopStyleVar(ctx)
end

function DrawMIDILearn(track, fx, param)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
	local visible = reaper.ImGui_BeginChild(ctx, 'MIDI_Child', 0, 20 + win_padding_y * 2, reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor(track_color, 2))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), BrighterColor(track_color, 2))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), BrighterColor(track_color, 2))
		local width, height = reaper.ImGui_GetWindowSize(ctx)	
		local x, y = reaper.ImGui_GetCursorPos(ctx)

		local midi_learn_active
		if t_pm_data.midi_learn then
			midi_learn_active = 1
		else
			midi_learn_active = 0
		end

		-- rv_midi_active, midi_learn_active = ToggleButton(ctx, "MIDI Learn", midi_learn_active, width - (win_padding_x * 2), 20)		
		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), track_color)
		rv_midi_active, midi_learn_active = reaper.ImGui_Checkbox(ctx, "MIDI LEARN", midi_learn_active)				
		reaper.ImGui_PopStyleColor(ctx)
		reaper.ImGui_PopFont(ctx)	
		ToolTip("currently not working due to a Reaper bug")	

		if rv_midi_active then
			midi_learn_active = midi_learn_active and 1 or 0
			-- reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.active", t_pm_data.midi_learn)
			local current_val = reaper.TrackFX_GetParam(track, fx, param)
			reaper.TrackFX_SetParam(track, fx, param, current_val) -- Safety to set as last touched FX parameter
			-- reaper.SetCursorContext(1) -- Set focus back to arrange
			-- reaper.ImGui_SetKeyboardFocusHere(ctx)
			Command(41144) -- FX: Set MIDI learn for last touched FX parameter
			GetPMData(track, fx, param)
		end

		reaper.ImGui_PopStyleColor(ctx, 3)
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx)
	reaper.ImGui_PopStyleVar(ctx)
end

function DrawNativeLFO(track, fx, param)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
	local lfo_child_size = 20
	if t_pm_data.lfo_active == 1 then lfo_child_size = 200 end
	local visible = reaper.ImGui_BeginChild(ctx, 'LFO_Child', 0, lfo_child_size + win_padding_y * 2, reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then

		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), track_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), track_color)
		local width, height = reaper.ImGui_GetWindowSize(ctx)	
		local x, y = reaper.ImGui_GetCursorPos(ctx)

		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), track_color)
		local checkbox_lfo = t_pm_data.lfo_active
		rv_lfo_active, checkbox_lfo = reaper.ImGui_Checkbox(ctx, "NATIVE LFO", checkbox_lfo)				
		reaper.ImGui_PopStyleColor(ctx)
		reaper.ImGui_PopFont(ctx)

		if rv_lfo_active then
			t_pm_data.lfo_active = checkbox_lfo and 1 or 0
			ToggleNativeLFO(track, fx, param, t_pm_data.lfo_active)
		end

		if t_pm_data.lfo_active == 1 then

			reaper.ImGui_Dummy(ctx, 0, 0)

			local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
			local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
			reaper.ImGui_DrawList_AddLine(draw_list, x - win_padding_x, y, x + width - win_padding_x, y, DarkerColor(track_color))

			reaper.ImGui_Dummy(ctx, 0, 10)

			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the sliders
			-- LFO shape
			local shape_format
			if t_lfo_params.lfo_shape < 1 then
				shape_format = "Sine"
			elseif t_lfo_params.lfo_shape >= 1 and t_lfo_params.lfo_shape < 2 then
				shape_format = "Square"
			elseif t_lfo_params.lfo_shape >= 2 and t_lfo_params.lfo_shape < 3 then
				shape_format = "Saw Down"
			elseif t_lfo_params.lfo_shape >= 3 and t_lfo_params.lfo_shape < 4 then
				shape_format = "Saw Up"						
			elseif t_lfo_params.lfo_shape >= 4 and t_lfo_params.lfo_shape < 5 then
				shape_format = "Triangle"
			elseif t_lfo_params.lfo_shape == 5 then
				shape_format = "Random"												
			end
			local text_lfo_shape = "Shape"
			local text_lfo_shape_clipped = ClipText(text_lfo_shape, GetLabelMaxWidth())		
			rv_lfo_shape, t_lfo_params.lfo_shape = reaper.ImGui_SliderDouble(ctx, text_lfo_shape_clipped, t_lfo_params.lfo_shape, 0, 5, shape_format, reaper.ImGui_SliderFlags_NoInput())
			if rv_lfo_shape then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.shape", t_lfo_params.lfo_shape)
			end
			if text_lfo_shape_clipped ~= text_lfo_shape then ToolTip(text_lfo_shape) end

			-- LFO speed
			local text_lfo_speed = "Speed"
			local text_lfo_speed_clipped = ClipText(text_lfo_speed, GetLabelMaxWidth())		
			if t_lfo_params.lfo_temposync == 0 then
				rv_lfo_speed, t_lfo_params.lfo_speed = reaper.ImGui_SliderDouble(ctx, text_lfo_speed_clipped, t_lfo_params.lfo_speed, 0.0039, 8, formatIn, reaper.ImGui_SliderFlags_Logarithmic() | reaper.ImGui_SliderFlags_NoInput())
				if rv_lfo_speed then
					reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", t_lfo_params.lfo_speed)
					-- if is_selected then
						reaper.ImGui_SetItemDefaultFocus(ctx)
					-- end					
				end	
			else
				-- Sloppy code
				local beat = {"1/16", "1/8", "1/4", "1/2", "1/1", "2/1"}			
				local current_item = 0
				if t_lfo_params.lfo_speed == 0.25 then combo_preview_value = beat[1]
				elseif t_lfo_params.lfo_speed > 0.25 and t_lfo_params.lfo_speed <= 0.5 then combo_preview_value = beat[2]
				elseif t_lfo_params.lfo_speed > 0.5 and t_lfo_params.lfo_speed <= 1 then combo_preview_value = beat[3]
				elseif t_lfo_params.lfo_speed > 1 and t_lfo_params.lfo_speed <= 2 then combo_preview_value = beat[4]
				elseif t_lfo_params.lfo_speed > 2 and t_lfo_params.lfo_speed <= 4 then combo_preview_value = beat[5]
				elseif t_lfo_params.lfo_speed > 4 and t_lfo_params.lfo_speed <= 8 then combo_preview_value = beat[6]					
				end

				if reaper.ImGui_BeginCombo(ctx, text_lfo_speed_clipped, combo_preview_value) then
					for i,v in ipairs(beat) do
						local is_selected = current_item == i
						if reaper.ImGui_Selectable(ctx, beat[i], is_selected) then
							current_item = i
							if current_item == 1 then
								reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 0.25)
							elseif current_item == 2 then
								reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 0.5)
							elseif current_item == 3 then
								reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 1)
							elseif current_item == 4 then
								reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 2)
							elseif current_item == 5 then
								reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 4)
							elseif current_item == 6 then
								reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 8)																												
							end
						end

						-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
						if is_selected then
							reaper.ImGui_SetItemDefaultFocus(ctx)
						end
					end
					reaper.ImGui_EndCombo(ctx)
				end			
			end
			if text_lfo_speed_clipped ~= text_lfo_speed then ToolTip(text_lfo_speed) end	

			-- LFO phase
			local text_lfo_phase = "Phase"
			local text_lfo_phase_clipped = ClipText(text_lfo_phase, GetLabelMaxWidth())
			rv_lfo_phase, t_lfo_params.lfo_phase = reaper.ImGui_SliderDouble(ctx, text_lfo_phase_clipped, t_lfo_params.lfo_phase, 0, 1, formatIn, reaper.ImGui_SliderFlags_NoInput())
			if rv_lfo_phase then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.phase", t_lfo_params.lfo_phase)
			end				
			if text_lfo_phase_clipped ~= text_lfo_phase then ToolTip(text_lfo_phase) end	

			-- LFO strength
			local text_lfo_strength = "Strength"
			local text_lfo_strength_clipped = ClipText(text_lfo_strength, GetLabelMaxWidth())
			rv_lfo_strength, t_lfo_params.lfo_strength = reaper.ImGui_SliderDouble(ctx, text_lfo_strength_clipped, t_lfo_params.lfo_strength, 0, 1, string.format("%.2f", t_lfo_params.lfo_strength * 100), reaper.ImGui_SliderFlags_NoInput())
			if rv_lfo_strength then				
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.strength", t_lfo_params.lfo_strength)
			end				
			if text_lfo_strength_clipped ~= text_lfo_strength then ToolTip(text_lfo_strength) end	
			if reaper.ImGui_IsItemActive(ctx) then
				lfo_strength_adjust = 1
			else
				lfo_strength_adjust = nil
			end
			reaper.ImGui_PopStyleVar(ctx)

			-- LFO direction
			-- local direction_format
			-- if t_lfo_params.lfo_dir == -1 then
			-- 	direction_format = "Negative"
			-- elseif t_lfo_params.lfo_dir > -1 and t_lfo_params.lfo_dir < 1 then
			-- 	direction_format = "Centered"
			-- elseif t_lfo_params.lfo_dir == 1 then
			-- 	direction_format = "Positive"	
			-- end	
			-- local text_lfo_dir = "Direction"
			-- text_lfo_dir = ClipText(text_lfo_dir, GetLabelMaxWidth())		
			-- rv_lfo_dir, t_lfo_params.lfo_dir = reaper.ImGui_SliderDouble(ctx, text_lfo_dir, t_lfo_params.lfo_dir, -1, 1, direction_format)
			-- if rv_lfo_dir then
			-- 	reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir", t_lfo_params.lfo_dir)
			-- end		
		
			local radio_neg, radio_cent, radio_pos = 1, 1, 1
			if t_lfo_params.lfo_dir == -1 then radio_neg = 0 end
			if t_lfo_params.lfo_dir == 0 then radio_cent = 0 end
			if t_lfo_params.lfo_dir == 1 then radio_pos = 0 end

			if reaper.ImGui_RadioButtonEx(ctx, "N", 0, radio_neg) then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir", -1)
			end
			ToolTip("Negative")
			reaper.ImGui_SameLine(ctx) 
			if reaper.ImGui_RadioButtonEx(ctx, "C", 0, radio_cent) then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir", 0)
			end			
			ToolTip("Centered")
			reaper.ImGui_SameLine(ctx) 
			if reaper.ImGui_RadioButtonEx(ctx, "P", 0, radio_pos) then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir", 1)
			end
			ToolTip("Positive")
			-- reaper.ImGui_SameLine(ctx) 
			-- reaper.ImGui_Text(ctx, text_lfo_dir)	

			-- Tempo Sync
			rv_temposync = reaper.ImGui_Checkbox(ctx, "Tempo Sync", t_lfo_params.lfo_temposync)
			if rv_temposync then
				if t_lfo_params.lfo_temposync == 0 then
					t_lfo_params.lfo_temposync = 1 
				else
					t_lfo_params.lfo_temposync = 0
				end				
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.temposync", t_lfo_params.lfo_temposync)
				GetNativeLFOData(track, fx, param)				
				if t_lfo_params.lfo_temposync == 1 and t_lfo_params.lfo_speed > 8 then reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 8) end -- LFO speed range can be outside of native slider range so I need to clip it				
			end

			-- Free Running
			if reaper.ImGui_Checkbox(ctx, "Free-Running", t_lfo_params.lfo_free) then
				if t_lfo_params.lfo_free == 1 then t_lfo_params.lfo_free = 0 else t_lfo_params.lfo_free = 1 end
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.free", t_lfo_params.lfo_free)
			end

		end
		reaper.ImGui_PopStyleColor(ctx, 2)
		reaper.ImGui_EndChild(ctx)
	end
	hover_lfo = reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_RectOnly())
	reaper.ImGui_PopStyleColor(ctx)
	reaper.ImGui_PopStyleVar(ctx)
end

function DrawNativeACS(track, fx, param)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
	local acs_child_size = 20
	if t_pm_data.acs_active == 1 then acs_child_size = 200 end
	local visible = reaper.ImGui_BeginChild(ctx, 'ACS_Child', 0, acs_child_size + win_padding_y * 2, reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then

		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), track_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), track_color)		
		local width, height = reaper.ImGui_GetWindowSize(ctx)	
		local x, y = reaper.ImGui_GetCursorPos(ctx)

		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), track_color)
		local checkbox_acs = t_pm_data.acs_active
		rv_acs_active, checkbox_acs = reaper.ImGui_Checkbox(ctx, "NATIVE ACS", checkbox_acs)				
		reaper.ImGui_PopStyleColor(ctx)
		reaper.ImGui_PopFont(ctx)		

		if rv_acs_active then
			t_pm_data.acs_active = checkbox_acs and 1 or 0
			ToggleNativeACS(track, fx, param, t_pm_data.acs_active)
		end

		if t_pm_data.acs_active == 1 then

			reaper.ImGui_Dummy(ctx, 0, 0)

			local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
			local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
			reaper.ImGui_DrawList_AddLine(draw_list, x - win_padding_x, y, x + width - win_padding_x, y, DarkerColor(track_color))

			reaper.ImGui_Dummy(ctx, 0, 10)

			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the sliders
			-- acs strength
			local text_acs_strength = "Strength"
			local text_acs_strength_clipped = ClipText(text_acs_strength, GetLabelMaxWidth())
			rv_acs_strength, t_acs_params.acs_strength = reaper.ImGui_SliderDouble(ctx, text_acs_strength_clipped, t_acs_params.acs_strength, 0, 1, string.format("%.2f", t_acs_params.acs_strength * 100), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_strength then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.strength", t_acs_params.acs_strength)
			end	
			if text_acs_strength_clipped ~= text_acs_strength then ToolTip(text_acs_strength) end	

			if reaper.ImGui_IsItemActive(ctx) then
				acs_strength_adjust = 1
			else
				acs_strength_adjust = nil
			end

			-- acs attack
			local text_acs_attack = "Attack"
			local text_acs_attack_clipped = ClipText(text_acs_attack, GetLabelMaxWidth())
			rv_acs_attack, t_acs_params.acs_attack = reaper.ImGui_SliderDouble(ctx, text_acs_attack_clipped, t_acs_params.acs_attack, 0, 1000, string.format("%.0f", t_acs_params.acs_attack), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_attack then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.attack", t_acs_params.acs_attack)
			end	
			if text_acs_attack_clipped ~= text_acs_attack then ToolTip(text_acs_attack) end	

			-- acs release
			local text_acs_release = "Release"
			local text_acs_release_clipped = ClipText(text_acs_release, GetLabelMaxWidth())
			rv_acs_release, t_acs_params.acs_release = reaper.ImGui_SliderDouble(ctx, text_acs_release_clipped, t_acs_params.acs_release, 0, 1000,string.format("%.0f", t_acs_params.acs_release), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_release then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.release", t_acs_params.acs_release)
			end	
			if text_acs_release_clipped ~= text_acs_release then ToolTip(text_acs_release) end	

			-- min volume
			local text_acs_dblo = "Min Vol"
			local text_acs_dblo_clipped = ClipText(text_acs_dblo, GetLabelMaxWidth())
			rv_acs_dblo, t_acs_params.acs_dblo = reaper.ImGui_SliderDouble(ctx, text_acs_dblo_clipped, t_acs_params.acs_dblo, -60, 12, string.format("%.2f", t_acs_params.acs_dblo), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_dblo then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dblo", t_acs_params.acs_dblo)
			end	
			if text_acs_dblo_clipped ~= text_acs_dblo then ToolTip(text_acs_dblo) end	

			-- min volume
			local text_acs_dbhi = "Max Vol"
			local text_acs_dbhi_clipped = ClipText(text_acs_dbhi, GetLabelMaxWidth())
			rv_acs_dbhi, t_acs_params.acs_dbhi = reaper.ImGui_SliderDouble(ctx, text_acs_dbhi_clipped, t_acs_params.acs_dbhi, -60, 12, string.format("%.2f", t_acs_params.acs_dbhi), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_dbhi then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dbhi", t_acs_params.acs_dbhi)
			end	
			if text_acs_dbhi_clipped ~= text_acs_dbhi then ToolTip(text_acs_dbhi) end	
			reaper.ImGui_PopStyleVar(ctx)						

			-- acs direction
			-- local direction_format
			-- if t_acs_params.acs_dir == -1 then
			-- 	direction_format = "Negative"
			-- elseif t_acs_params.acs_dir > -1 and t_acs_params.acs_dir < 1 then
			-- 	direction_format = "Centered"
			-- elseif t_acs_params.acs_dir == 1 then
			-- 	direction_format = "Positive"	
			-- end	
			-- local text_acs_dir = "Direction"
			-- text_acs_dir = ClipText(text_acs_dir, GetLabelMaxWidth())		
			-- rv_acs_dir, t_acs_params.acs_dir = reaper.ImGui_SliderDouble(ctx, text_acs_dir, t_acs_params.acs_dir, -1, 1, direction_format)
			-- if rv_acs_dir then
			-- 	reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dir", t_acs_params.acs_dir)
			-- end		
		
			-- Strangely 1 = OFF and 0 = ON
			local radio_neg, radio_cent, radio_pos = 1, 1, 1
			if t_acs_params.acs_dir == -1 then radio_neg = 0 end
			if t_acs_params.acs_dir == 0 then radio_cent = 0 end
			if t_acs_params.acs_dir == 1 then radio_pos = 0 end

			if reaper.ImGui_RadioButtonEx(ctx, "N", 0, radio_neg) then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dir", -1)
			end
			ToolTip("Negative")
			reaper.ImGui_SameLine(ctx) 
			if reaper.ImGui_RadioButtonEx(ctx, "C", 0, radio_cent) then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dir", 0)
			end			
			ToolTip("Centered")
			reaper.ImGui_SameLine(ctx) 
			if reaper.ImGui_RadioButtonEx(ctx, "P", 0, radio_pos) then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dir", 1)
			end
			ToolTip("Positive")
			-- reaper.ImGui_SameLine(ctx) 
			-- reaper.ImGui_Text(ctx, text_acs_dir)	

			-- Channels
			local text_acs_chan = "Channels"
			local text_acs_chan_clipped = ClipText(text_acs_chan, GetLabelMaxWidth())		

			-- Sloppy code
			local chan = {"1/2", "3/4", "5/6", "7/8"}			
			local current_item = 0
			if t_acs_params.acs_chan >= 0 and t_acs_params.acs_chan < 2 then combo_preview_value = chan[1]				
			elseif t_acs_params.acs_chan >= 2 and t_acs_params.acs_chan < 4 then combo_preview_value = chan[2]
			elseif t_acs_params.acs_chan >= 4 and t_acs_params.acs_chan < 6 then combo_preview_value = chan[3]
			elseif t_acs_params.acs_chan >= 6 and t_acs_params.acs_chan < 8 then combo_preview_value = chan[4]
			end

			local track_ch = (reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") * 0.5)
			-- local actual_chan -- after track channel evaluation
			for i=1, #chan do
				if i > track_ch then
					chan[i] = nil
				end
			end

			if reaper.ImGui_BeginCombo(ctx, text_acs_chan_clipped, combo_preview_value) then
				for i,v in ipairs(chan) do
					local is_selected = current_item == i
					if reaper.ImGui_Selectable(ctx, chan[i], is_selected) then
						current_item = i
						if current_item == 1 then
							reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 0)						
						elseif current_item == 2 then
							reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 2)
						elseif current_item == 3 then
							reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 4)
						elseif current_item == 4 then
							reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 6)																												
						end
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.stereo", 1)
					end

					-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
					if is_selected then
						reaper.ImGui_SetItemDefaultFocus(ctx)
					end
				end
				reaper.ImGui_EndCombo(ctx)
			end	
			if text_acs_chan_clipped ~= text_acs_chan then ToolTip(text_acs_chan) end				
		end
		reaper.ImGui_PopStyleColor(ctx, 2)
		reaper.ImGui_EndChild(ctx)
	end
	hover_acs = reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_RectOnly())
	reaper.ImGui_PopStyleColor(ctx)
	reaper.ImGui_PopStyleVar(ctx)
end

function SineWave(draw_list, x, y, width, height, color, thickness)
	local points = 40
	local step = (math.pi * 2) / points  -- Step size for sine function
	local prev_x, prev_y = x, y + height / 2  -- Start at middle left

	for i = 1, points do
		local t = step * i
		local new_x = x + (i / points) * width
		local new_y = y + (math.sin(t) * (height / 2)) + (height / 2)

		reaper.ImGui_DrawList_AddLine(draw_list, prev_x, prev_y, new_x, new_y, color, thickness)
		prev_x, prev_y = new_x, new_y
	end
end

function ADEnvelope(draw_list, x, y, width, height, color, thickness)
		-- Attack: vertical line from left (start of x-axis)
		local attack_x = x
		local attack_y_start = y
		local attack_y_end = y + height

		-- Decay: diagonal line from attack's end to x axis (y=0)
		local decay_x_start = attack_x
		local decay_y_start = y
		local decay_x_end = x + width
		local decay_y_end = y + height

		-- Control point for the curve
		local control_x = decay_x_start + (decay_x_end - decay_x_start) / 2
		local control_y = decay_y_start + (decay_y_end - decay_y_start) / 1  -- You can adjust this for more control over the curve    

		-- Draw attack line (vertical)
		reaper.ImGui_DrawList_AddLine(draw_list, attack_x, attack_y_start, attack_x, attack_y_end, color, thickness)   

		-- Draw decay curve (quadratic Bezier)
		local num_segments = 30  -- Number of segments for the curve (more segments = smoother curve)
		for i = 0, num_segments do
				local t = i / num_segments
				local u = 1 - t
				-- Calculate the quadratic bezier curve at each segment
				local px = u * u * decay_x_start + 2 * u * t * control_x + t * t * decay_x_end
				local py = u * u * decay_y_start + 2 * u * t * control_y + t * t * decay_y_end
				if i > 0 then
						reaper.ImGui_DrawList_AddLine(draw_list, prev_px, prev_py, px, py, color, thickness)
				end
				prev_px, prev_py = px, py
		end
end

function Midi(draw_list, x, y, width, height, color, thickness)
		local window_pos_x, window_pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
		
		local border = 0

		-- Define circle parameters
		local large_circle_radius = width / 2
		local small_circle_radius = 1
		
		-- Center position for the large circle   
		local center = {
				x = x + large_circle_radius + border,
				y = y + large_circle_radius + border
		}        
		
		-- Draw empty large circle
		reaper.ImGui_DrawList_AddCircle(draw_list, center.x, center.y, large_circle_radius, color, 32, thickness)
		
		-- Draw 5 small filled circles in a semi-circle in the lower part
		local num_small_circles = 5
		local pi = math.pi
		
		-- We'll draw in the lower semi-circle, from pi/2 to 3pi/2
		local start_angle = 0
		local end_angle = pi
		local angle_step = (end_angle - start_angle) / (num_small_circles - 1)
		
		-- Position small circles along the arc in the lower half
		for i = 0, num_small_circles - 1 do
				local angle = start_angle + i * angle_step
				
				-- Position small circles slightly inside the large circle
				local distance_from_center = large_circle_radius * 0.55
				
				local small_circle_pos = {
						x = center.x + math.cos(angle) * distance_from_center,
						y = center.y + math.sin(angle) * distance_from_center
				}
				
				-- Draw filled small circle
				reaper.ImGui_DrawList_AddCircleFilled(draw_list, small_circle_pos.x, small_circle_pos.y, small_circle_radius, color, 16)
		end
end

function Locks(draw_list, x, y, width, height, color, thickness, state, hovered)
	local outline = false
		-- Calculate dimensions
		local lock_width = width * 0.85
		local lock_height = height * 0.65
		local shackle_width = lock_width * 0.65
		local shackle_height = height * 0.35
		
		-- Center the lock horizontally
		local center_x = x + width * 0.5
		local lock_x = center_x - lock_width * 0.5
		
		-- Position the base of the lock at the bottom
		local lock_y = y + height - lock_height
		
		-- Black outline color
		local outline_color = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1)  -- Black color with full alpha
		local outline_thickness = 1 -- 1 pixel outline
		
		-- Draw the body of the lock (rectangle with rounded corners)
		local rounding = lock_width * 0.2
		
		-- First draw the filled shape with the specified color
		reaper.ImGui_DrawList_AddRectFilled(
				draw_list,
				lock_x, lock_y,
				lock_x + lock_width, lock_y + lock_height,
				color, rounding
		)
		
		if (state == 1 or hovered) and outline then 
			-- Then draw the outline around the body
			reaper.ImGui_DrawList_AddRect(
					draw_list,
					lock_x, lock_y,
					lock_x + lock_width, lock_y + lock_height,
					outline_color, rounding, nil, outline_thickness
			)
	end
		
		-- Draw curved shackle
		local shackle_left_x = center_x - shackle_width * 0.5
		local shackle_right_x = center_x + shackle_width * 0.5
		local shackle_bottom_y = lock_y
		local shackle_top_y = lock_y - shackle_height
		
		-- Draw shackle fills with the original color
		-- Left vertical line of shackle
		if (state == 1 or hovered) then 
				reaper.ImGui_DrawList_AddLine(
						draw_list,
						shackle_left_x, shackle_bottom_y,
						shackle_left_x, shackle_top_y + shackle_height * 0.3,
						color, thickness
				)
				
				if outline then
					-- Add outline to left vertical line
					reaper.ImGui_DrawList_AddLine(
							draw_list,
							shackle_left_x - outline_thickness/2, shackle_bottom_y,
							shackle_left_x - outline_thickness/2, shackle_top_y + shackle_height * 0.3,
							outline_color, outline_thickness
					)
			end
		end
		
		-- Right vertical line of shackle
		reaper.ImGui_DrawList_AddLine(
				draw_list,
				shackle_right_x, shackle_bottom_y,
				shackle_right_x, shackle_top_y + shackle_height * 0.3,
				color, thickness
		)
		
	if (state == 1 or hovered) and outline then     
			reaper.ImGui_DrawList_AddLine(
					draw_list,
					shackle_right_x + outline_thickness/2, shackle_bottom_y,
					shackle_right_x + outline_thickness/2, shackle_top_y + shackle_height * 0.3,
					outline_color, outline_thickness
			)
	end
		
		-- Curved top part of the shackle
		local arc_segments = 24  -- Number of segments for smooth arc
		
		-- Starting points for the arc
		local start_x = shackle_left_x
		local start_y = shackle_bottom_y - shackle_height * 0.7
		local end_x = shackle_right_x
		local end_y = shackle_bottom_y - shackle_height * 0.7
		
		-- Draw a proper semi-circle connecting the top of the vertical lines
		local prev_x, prev_y = start_x, start_y
		
		-- First draw the filled arc with original color
		for i = 0, arc_segments do
				-- Calculate angle for this segment (0 to 180 degrees)
				local angle = i * (math.pi / arc_segments)
				
				-- Calculate point on the arc
				local curr_x = center_x + (shackle_width * 0.5) * math.cos(angle + math.pi)
				local curr_y = start_y - shackle_height * 0.3 * math.sin(angle)
				
				-- Draw line segment
				reaper.ImGui_DrawList_AddLine(
						draw_list,
						prev_x, prev_y,
						curr_x, curr_y,
						color, thickness
				)
				
				prev_x, prev_y = curr_x, curr_y
		end
		
		-- Now draw the outline arc
		-- Outer outline
		if (state == 1 or hovered) and outline then 
			prev_x, prev_y = start_x, start_y
			local outer_offset = outline_thickness/2
			
			for i = 0, arc_segments do
					local angle = i * (math.pi / arc_segments)
					local curr_x = center_x + (shackle_width * 0.5 + outer_offset) * math.cos(angle + math.pi)
					local curr_y = start_y - (shackle_height * 0.3 + outer_offset) * math.sin(angle)
					
					reaper.ImGui_DrawList_AddLine(
							draw_list,
							prev_x, prev_y,
							curr_x, curr_y,
							outline_color, outline_thickness
					)
					
					prev_x, prev_y = curr_x, curr_y
			end
	end   
end

function Plus(draw_list, x, y, width, height, color, thickness)
		-- Use more space - increase the size of the plus
		local plus_width = width * 0.8
		local plus_height = height * 0.8
		
		-- Center the plus horizontally and vertically
		local center_x = x + width * 0.5
		local center_y = y + height * 0.5
		
		-- Calculate the positions for the horizontal line
		local h_line_left_x = center_x - plus_width * 0.5
		local h_line_right_x = center_x + plus_width * 0.5 + 0.5
		
		-- Calculate the positions for the vertical line
		local v_line_top_y = center_y - plus_height * 0.5
		local v_line_bottom_y = center_y + plus_height * 0.5
		
		-- Draw horizontal rectangle
		local rect_height = thickness
		local rect_y = center_y - rect_height * 0.5
		
		reaper.ImGui_DrawList_AddRectFilled(
				draw_list,
				h_line_left_x, rect_y,
				h_line_right_x, rect_y + rect_height,
				color
		)
		
		-- Draw vertical rectangle
		local rect_width = thickness
		local rect_x = center_x - rect_width * 0.5
		
		reaper.ImGui_DrawList_AddRectFilled(
				draw_list,
				rect_x, v_line_top_y,
				rect_x + rect_width, v_line_bottom_y,
				color
		)
end

function DrawIcon(width, height, color, track, fx, param, state, icon)	
	local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
	local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
	if not width then width = 50 end
	if not height then height = 25 end 

	-- Use ImGui color conversion (RGBA with values from 0 to 1)
	local normal_color, hover_color
	if color == UI_color then
		normal_color = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(255), ColourToFloat(255), ColourToFloat(255), 0.8)
		hover_color = reaper.ImGui_ColorConvertDouble4ToU32(ColourToFloat(255), ColourToFloat(255), ColourToFloat(255), 1)
	else
		normal_color = DarkerColor(color)
		hover_color = color
	end
	local disabled_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.4) 
	local normal_bg = reaper.ImGui_ColorConvertDouble4ToU32(0.1, 0.1, 0.1, 0.7) -- Dark gray
	local hover_bg = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1)  -- Slightly lighter

	-- Invisible button (actual interactive element)
	reaper.ImGui_SetCursorPos(ctx, reaper.ImGui_GetCursorPos(ctx)) -- Ensure correct placement
	reaper.ImGui_InvisibleButton(ctx, 'Button', width, height)

	-- Now we check if it's hovered
	local hovered = reaper.ImGui_IsItemHovered(ctx)

	-- Draw background shape (rounded rectangle)
	local bg_color
	if hovered then bg_color = hover_bg else bg_color = normal_bg end
	reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width, y + height + 4, bg_color, 5)

	-- Draw icon over background
	local icon_color
	if state == 1 then
		if hovered then icon_color = hover_color else icon_color = normal_color end
	else
		if hovered then icon_color = hover_color else icon_color = disabled_color end
	end
	-- if hovered then icon_color = hover_color else icon_color = normal_color end
	if icon == 1 then
		-- SineWave(draw_list, x, y, width, height, icon_color, 2)
		SineWave(draw_list, x, y, width, height, icon_color, 2)
		ToolTip("Native LFO")
	elseif icon == 2 then
		ADEnvelope(draw_list, x, y, width, height, icon_color, 2)
		ToolTip("Native Audio Follower")
	elseif icon == 3 then
		Midi(draw_list, x, y, 13, height, icon_color, 2)
		ToolTip("MIDI learn, currently not working due to a Reaper bug")
	end	

	-- On button click
	if reaper.ImGui_IsItemClicked(ctx) then
		-- reaper.ShowMessageBox('Sine Wave Button Clicked!', 'Info', 0)
		if state == nil then state = 0 end
		state = 1 - state				
		if icon == 1 then
			ToggleNativeLFO(track, fx, param, state)
		elseif icon == 2 then
			ToggleNativeACS(track, fx, param, state)
		elseif icon == 3 then			
			Command(41144) -- FX: Set MIDI learn for last touched FX parameter
			GetPMData(track, fx, param)
		end
	end
end  

function GradientButton(ctx, label, x, y, width, height, colorStart, colorEnd, horizontal)
	local pressed, hovered
		-- Calculate position
		local pos_x, pos_y
		if x == nil or y == nil then
				pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
		else
				pos_x, pos_y = x, y
		end
		
		-- Calculate size
		local btn_width = width or 100
		local btn_height = height or 30
		
		-- Set up unique ID for the button
		local id = label .. "##gradient"
		
		horizontal = horizontal ~= false     -- Default to horizontal gradient
		
		-- Create invisible button for behavior
		reaper.ImGui_SetCursorScreenPos(ctx, pos_x, pos_y)
		reaper.ImGui_InvisibleButton(ctx, id, btn_width, btn_height)
		
		if reaper.ImGui_IsItemHovered(ctx) then 
			hovered = true 
			if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
				pressed = true
			end
		end

		if pressed then
			colorStart = colorStart
			colorEnd = colorEnd
		elseif hovered then
				-- colorStart = BrighterColor2(colorStart, 0.2)
				-- colorEnd = BrighterColor2(colorEnd, 0.2)
			colorStart = colorStart
			colorEnd = colorEnd        
		else
			colorStart = DarkerColor2(colorStart, 0.1)
			colorEnd = DarkerColor2(colorEnd, 0.1)
			-- colorStart = colorStart
			-- colorEnd = colorEnd
		end   
		
		-- Get the current draw list for rendering
		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

		-- Rounding for corners
		local rounding = 4.0
		
		-- Draw gradient background
		if horizontal then
				reaper.ImGui_DrawList_AddRectFilledMultiColor(
						draw_list,
						pos_x, pos_y, pos_x + btn_width, pos_y + btn_height,
						colorStart, colorEnd, colorEnd, colorStart
				)
		else
				reaper.ImGui_DrawList_AddRectFilledMultiColor(
						draw_list,
						pos_x, pos_y, pos_x + btn_width, pos_y + btn_height,
						colorStart, colorStart, colorEnd, colorEnd
				)
		end   
		
		-- Draw text label
		local text_width = reaper.ImGui_CalcTextSize(ctx, label)
		local text_pos_x = pos_x + (btn_width - text_width) * 0.5
		local text_pos_y = pos_y + (btn_height - reaper.ImGui_GetTextLineHeight(ctx)) * 0.5
		
		-- Draw text
		text_color = BrighterColor2(white, 0.2)
		reaper.ImGui_DrawList_AddText(draw_list, text_pos_x, text_pos_y, text_color, label)
		
		-- Reset cursor position
		-- reaper.ImGui_SetCursorScreenPos(ctx, pos_x, pos_y + btn_height + 2)
		
		return pressed
end

-- Custom Collapsing Header function
function CustomCollapsingHeader(ctx, id, label, width, height, rounding)
	local hovered, clicked
		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
		local x, y = reaper.ImGui_GetCursorPos(ctx)
		local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)    
		pos_x = pos_x - win_padding_x
		local padding = 7
		local padding_text = 24

		-- Initialize header state if needed
		if custom_headers[id] == nil then custom_headers[id] = false end
		local is_open = custom_headers[id]

		-- Click detection
		reaper.ImGui_SetCursorPos(ctx, x, y) -- Reset cursor for button area
		reaper.ImGui_InvisibleButton(ctx, id, x + width - win_padding_x - 8, y + height * 0.5 - win_padding_y)

		if reaper.ImGui_IsItemHovered(ctx) then
			hovered = true
			if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
				clicked = true
					custom_headers[id] = not custom_headers[id]
				end
		end

		local color
		if clicked then
			color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.5)
		elseif hovered then
			color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.6)
		else
			color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.25)
		end

		-- Draw header background with rounded corners
		reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x, pos_y, pos_x + width, pos_y + height, color, rounding, reaper.ImGui_DrawFlags_RoundCornersBottomLeft())

		-- Triangle indicator position
		local tri_size = 8
		local tri_x = pos_x + padding
		local tri_y = pos_y + height * 0.5
		local tri_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1) -- White color

		-- Draw triangle indicator
		if is_open then
				-- Downward triangle (expanded)
				reaper.ImGui_DrawList_AddTriangleFilled(draw_list,
						tri_x, tri_y - tri_size * 0.5,
						tri_x + tri_size, tri_y - tri_size * 0.5,
						tri_x + tri_size * 0.5, tri_y + tri_size * 0.5,
						tri_color)
		else
				-- Right-facing triangle (collapsed)
				reaper.ImGui_DrawList_AddTriangleFilled(draw_list,
						tri_x, tri_y - tri_size * 0.5,
						tri_x + tri_size, tri_y,
						tri_x, tri_y + tri_size * 0.5,
						tri_color)
		end

		-- Draw text label
		reaper.ImGui_SetCursorPosX(ctx, padding_text + tri_size)
		reaper.ImGui_SetCursorPosY(ctx, y + (height * 0.5) - reaper.ImGui_GetTextLineHeight(ctx) * 0.5)
		reaper.ImGui_Text(ctx, label)

		-- Move cursor down to prevent overlap
		reaper.ImGui_SetCursorPosY(ctx, y + height + 2)

		return custom_headers[id]
end

function DrawLock(width, height, color, rounding, param_lock, track, fx, param)
	local hovered
		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
		local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)  

		-- Click detection
		reaper.ImGui_InvisibleButton(ctx, "##lock_button", width - 7, height)

		if reaper.ImGui_IsItemHovered(ctx) then
			hovered = true    	
			if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					param_lock = 1 - param_lock
					rv_param_lock = true

					-- Set the locked parameter as the last-touched one
					local current_val = reaper.TrackFX_GetParam(track, fx, param)
					reaper.TrackFX_SetParam(track, fx, param, current_val)
				end
		end

		local lock_color, bg_color
	if hovered then 
		bg_color = track_color
		lock_color = reaper.ImGui_ColorConvertDouble4ToU32(0.3, 0.3, 0.3, 1)
	elseif param_lock == 1 then
		bg_color = BrighterColor2(track_color, 0.1)
		lock_color = reaper.ImGui_ColorConvertDouble4ToU32(0.1, 0.1, 0.1, 1)
	else
			bg_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.25)
		lock_color = reaper.ImGui_ColorConvertDouble4ToU32(0.8, 0.8, 0.8, 1)    	    	
		end

		-- Draw header background
		reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x, pos_y, pos_x + width, pos_y + height, bg_color, rounding, reaper.ImGui_DrawFlags_RoundCornersBottom())    	

		-- Draw lock icon
	Locks(draw_list, pos_x + width * 0.2, pos_y + 2, 13, height - 4, lock_color, 2, param_lock, hovered)
	ToolTip("Lock Flashmob")

	return param_lock		
end

function DrawAddInstance(width, height, color, track, rounding)
	local hovered
		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
		local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)  

		-- Click detection
		reaper.ImGui_InvisibleButton(ctx, "##add_button", width - 7, height)

		if reaper.ImGui_IsItemHovered(ctx) then
			hovered = true    	
			if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
			reaper.TrackFX_AddByName(track, "../Scripts/ME/Flashmob_2/Flashmob.RfxChain", false, 1000)	-- last argument adds an instance if one is not found at the first FX chain index				
			mod_container_id = reaper.TrackFX_GetCount(track) - 1
			mod_container_table_id = mod_container_table_id + 1
			reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id, 1)
			reload_settings = true
				end
		end

		local plus_color, bg_color
	if hovered then 
		bg_color = track_color
		plus_color = reaper.ImGui_ColorConvertDouble4ToU32(0.3, 0.3, 0.3, 1)
	else
			bg_color = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.25)
		plus_color = reaper.ImGui_ColorConvertDouble4ToU32(0.8, 0.8, 0.8, 1)    	    	
		end

		-- Draw header background
		reaper.ImGui_DrawList_AddRectFilled(draw_list, pos_x, pos_y, pos_x + width, pos_y + height, bg_color, rounding, reaper.ImGui_DrawFlags_RoundCornersBottomRight())    	

		-- Draw lock icon
	Plus(draw_list, pos_x + width * 0.2, pos_y + 2, 13, height - 4, plus_color, 3)
	ToolTip("Add Flashmob Instance")
end


------------------------------------------------------------------------------------
-- MAIN FUNCTIONS
------------------------------------------------------------------------------------

function Init()

	-- Check if Reaper 7 at least is installed
	if reaper.GetAppVersion():match("^(%d).") < "7" then
		reaper.ShowMessageBox("This script requires Reaper V7", "WRONG REAPER VERSION", 0)
		return false
	end	

	-- Check if ReaPack is installed
	if not reaper.APIExists("ReaPack_BrowsePackages") then	
		reaper.MB("Please install ReaPack from Cfillion to install other dependencies'.\n\nThen restart REAPER and run the script again.\n\nVisit https://reapack.com\n", "You must install the ReaPack extension", 0)
		if reaper.CF_GetSWSVersion then
			reaper.CF_ShellExecute('https://reapack.com')
		else
			reaper.MB("You must download ReaPack at: https://reapack.com", 0)
		end
		return false
	end

    -- Manage missing dependencies
    local deps = {}
    if not reaper.CF_GetSWSVersion then
        deps[#deps + 1] = '"ReaTeam Extensions" SWS/S&M Extension'
    end   
    if not reaper.ImGui_GetVersion then
        deps[#deps + 1] = '"ReaTeam Extensions" ReaImGui'
    end
    if #deps ~= 0 then
        reaper.ShowMessageBox("Need Additional Packages\nPlease install them in the next window\nThen RESTART REAPER and run the script again", "MISSING DEPENDENCIES", 0)
        reaper.ReaPack_BrowsePackages(table.concat(deps, " OR "))
        return false
    end

    -- Check if ReaImGui 0.9.2 at least is installed
	local ok, ImGui = pcall(function()
		if not reaper.ImGui_GetBuiltinPath then
			error('ReaImGui is not installed or too old.')
		end
		package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
		return require 'imgui' '0.9.2'
	end)
	if not ok then
		reaper.MB("Please right-click and install 'ReaImGui: ReaScript binding for Dear ImGui'.\n\nThen restart REAPER and run the script again.\n", "ReaImGui API is not installed or too old", 0)
		reaper.ReaPack_BrowsePackages('"ReaTeam Extensions" ReaImGui')
		return false
	end

	local info = debug.getinfo(1,'S')
	script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]

	ctx = reaper.ImGui_CreateContext('FLASHMOB')

	fonts = {
	title = reaper.ImGui_CreateFont('sans-serif', 15),
	title_bold = reaper.ImGui_CreateFont('sans-serif', 15, reaper.ImGui_FontFlags_Bold()),
	small = reaper.ImGui_CreateFont('sans-serif', 10),
	small_bold = reaper.ImGui_CreateFont('sans-serif', 10, reaper.ImGui_FontFlags_Bold()),
	medium_small = reaper.ImGui_CreateFont('sans-serif', 11),
	medium_small_bold = reaper.ImGui_CreateFont('sans-serif', 11, reaper.ImGui_FontFlags_Bold()),	
	medium = reaper.ImGui_CreateFont('sans-serif', 13),
	medium_bold = reaper.ImGui_CreateFont('sans-serif', 13, reaper.ImGui_FontFlags_Bold())
	}
	for name, font in pairs(fonts) do
		reaper.ImGui_Attach(ctx, font)
	end	

	-- Global Variables
	flashmob_identifier = "vf_FLASHMOB_GEN"	
	defer_count = 0
	first_run = true
	param_is_valid = false
	result = -1
	mod_container_id = nil
	param_link = -1 -- -1 = param is not linked, 0 = Linked to selected instance of Flashmob but de-actived, 1 = Linked to selected instance of Flashmob and activated, 2 = Linked to another instance of Flashmob, 3 = Linked to an FX parameter other than Flashmob
	last_track = nil
	track_sel_changed = false
	last_param_guid_hack = nil
	t_last_param = {}
	t_pm_data = {}
	t_pm_lfo = {}
	t_pm_acs = {}	
	t_color_palette = ColorPalette()
	plots1, plots2, plots3, plots4, plots5, plots6 = nil
	rv_macro1, rv_macro2, rv_macro3, rv_macro4, rv_macro5, rv_macro6, rv_macro7, rv_macro8 = nil
	macro1, macro2, macro3, macro4, macro5, macro6, macro7, macro8 = nil
	macro_baseline1, macro_baseline2, macro_baseline3, macro_baseline4, macro_baseline5, macro_baseline6, macro_baseline7, macro_baseline8 = nil
	UI_color = -1499027713 -- Grey
	white = reaper.ImGui_ColorConvertDouble4ToU32(0.8, 0.8, 0.8, 1)	
	opened_tab = 1
	last_opened_tab = nil
	last_header_param = nil
	last_header_source = nil
	lfo_strength_adjust = nil
	acs_strength_adjust = nil
	native_tab_open = false
	reset_plot_lines = nil
	param_lock = 0
	rv_param_lock = nil	
	rv_flashmob = false
	t_flashmob_id = {}
	custom_headers = {} -- Store states of headers
	instance_nb = 0

	reload_settings = true

	-- Restore opened tab
	local _, saved_tab_setting = reaper.GetProjExtState(0, "vf_flashmob", "last_tab")
	if saved_tab_setting ~= "" then tab_to_load = tonumber(saved_tab_setting) end

	-- Restore header states
	local _, saved_header_setting = reaper.GetProjExtState(0, "vf_flashmob", "header_state")
	if saved_header_setting ~= "" then
		header_state_param = saved_header_setting:gsub("(%d),%d", "%1")
		header_state_source = saved_header_setting:gsub("%d,(%d)", "%1")
		header_state_param = tonumber(header_state_param)
		header_state_source = tonumber(header_state_source)
	else
		header_state_param = 1
		header_state_source = 1		
	end

	return true			
end


function Frame()
	local rv
	local project_switched = false
	local current_proj = reaper.EnumProjects(-1)
	if current_proj ~= last_proj then project_switched = true end

	-- Check proj state changes
	proj_state = reaper.GetProjectStateChangeCount(0)			
	if proj_state ~= previous_proj_state then proj_updated = true else proj_updated = nil end

	-- slower defer rate
	if defer_count >= 5 then
		defer_count = 0
		slower_defer_update = true
	else				
		defer_count = defer_count + 1
		slower_defer_update = nil
	end

	width, height = reaper.ImGui_GetWindowSize(ctx) 	
	win_padding_x, win_padding_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())	
	-- local scrollbar_size = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize())
	local custom_widget_width = width - (win_padding_x * 2)

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 10, val2In)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), 10, val2In)	

	-- track = reaper.GetSelectedTrack(0, 0)
	if param_lock == 0 then
		track = reaper.GetSelectedTrack2(0, 0, 1)
	end
	if track then	

		-- Refresh track name + color and detect if the first selected track have changed
		-- if first_run or (proj_state ~= previous_proj_state and param_lock == 0) then
		if first_run or proj_state ~= previous_proj_state or rv_param_lock then
			rv, track_name = reaper.GetTrackName(track)
			track_color = GetTrackColor(track)
			if track ~= last_track then
				track_sel_changed = true
			end
			last_track = track
		end  

		---------
		-- GUI --
		---------

		-- SELECTED TRACK NAME
		reaper.ImGui_PushFont(ctx, fonts.title_bold)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 0, 1) -- remove item spacing (remove empty space between track name and header)

		local item_inner_spacing = {reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing())}
		local rect_x, rect_y = reaper.ImGui_GetCursorScreenPos(ctx)
		local track_name_clipped = ClipText(track_name, width)		
		local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, track_name_clipped)
		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
		reaper.ImGui_DrawList_AddRectFilled(draw_list, rect_x - win_padding_x, rect_y - win_padding_y, (rect_x - win_padding_x) + width, (rect_y - win_padding_y) + text_h + 4, track_color, 12, reaper.ImGui_DrawFlags_RoundCornersTop())

		reaper.ImGui_SetNextItemAllowOverlap(ctx)
		reaper.ImGui_SameLine(ctx)
		local x, y = reaper.ImGui_GetCursorPos(ctx)
		local track_name_pos = (width - text_w) * 0.5 -- Center text
		if track_name_pos < 1 then track_name_pos = 1 end
		reaper.ImGui_SetCursorPos(ctx, track_name_pos, y - win_padding_y + 4)
		reaper.ImGui_Text(ctx, track_name_clipped)
		local x, y = reaper.ImGui_GetCursorPos(ctx)

		reaper.ImGui_PopStyleVar(ctx, 2)
		reaper.ImGui_PopStyleColor(ctx, 1)			
		if track_name_clipped ~= track_name then ToolTip(track_name) end		

		-- Draw small x button to close the window
		if reaper.ImGui_IsMouseHoveringRect(ctx, rect_x - win_padding_x, rect_y - win_padding_y, (rect_x - win_padding_x) + width, (rect_y - win_padding_y) + text_h + 4) then
			local x_color = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 0.7)

			if reaper.ImGui_IsMouseHoveringRect(ctx, rect_x + width - 28, rect_y - 4, rect_x + width - 28 + 18, rect_y - 4 + text_h + 4) then
				x_color = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1)
				if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					open = false
				end
			end			
			reaper.ImGui_DrawList_AddText(draw_list, rect_x + width - 28, rect_y - 4, x_color, "X")

		end			
		reaper.ImGui_PopFont(ctx)

		reaper.ImGui_SetCursorPos(ctx, x, y)

		-- local rv_flashmob, t_flashmob_id
		-- if first_run or proj_updated or project_switched or track_sel_changed then
		rv_flashmob, t_flashmob_id, flashmob_is_invalid = GetFlashmobInstances(track, flashmob_identifier)	
		-- end
		if rv_flashmob == true then
			-- reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 1)
			-- local mod_container_id
			if not mod_container_id then mod_container_id = t_flashmob_id[1] end						
			if not mod_container_table_id then mod_container_table_id = 1 end

			-- Support multiple instance of Flashmob (on each track with multiple instances, the last selected instance is stored to be recalled when re-selected)
			instance_nb = #t_flashmob_id
			if instance_nb > 1 then 

				local choose_first_instance
				local _, stored_instance = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 0)
				if stored_instance ~= "" then
					local instance_id = stored_instance:gsub("(%d),%d", "%1")
					local instance_table_id = stored_instance:gsub("%d,(%d)", "%1")					
					instance_id = tonumber(instance_id)
					instance_table_id = tonumber(instance_table_id)					
					if CheckIfStoredInstanceExist(track, flashmob_identifier, instance_id) then
						mod_container_id = instance_id
						mod_container_table_id = instance_table_id								
					else
						choose_first_instance = true
					end
				else
					choose_first_instance = true
				end		
				if choose_first_instance == true then
					mod_container_id = t_flashmob_id[1]	
					mod_container_table_id = 1				
					reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 1)					
				end					
			else
				mod_container_id = t_flashmob_id[1]
				mod_container_table_id = 1	
				reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 1)
			end

			if first_run or project_switched or (param_lock == 0 and (track_sel_changed or slower_defer_update)) then
				param_is_valid, result = GetLastTouchedFXParam(track)
			end

			-- Get param link mode
			if param_is_valid == true then -- If there is a valid last touched parameter
				if t_pm_data.link_source_fx and t_pm_data.link_source_fx > -1 then
					param_link = 3 -- Linked to an FX parameter other than Flashmob
					for i=1, #t_flashmob_id do
						if t_flashmob_id[i] == t_pm_data.link_source_fx then
							param_link = 2 -- Linked to another instance of Flashmob
							if t_flashmob_id[i] == mod_container_id then
								if t_pm_data.link_active == 1 then
									param_link = 1 -- Linked to selected instance of Flashmob and activated
									break
								else
									param_link = 0 -- Linked to selected instance of Flashmob and de-activated
									break
								end
							end
						end
					end
				else
					param_link = -1 -- param is not linked
				end
			end

			if reload_settings  == true then				
				if header_state_param == 1 then
					custom_headers["Header_Param"] = true
				else
					custom_headers["Header_Param"] = false
				end	
			end	

			local header_state_param
			reaper.ImGui_PushFont(ctx, fonts.medium_bold)
			-- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the collapse header			
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 1)

			local header_name = "FX PARAMETER"
			header_name = ClipText(header_name, width - win_padding_x - 60)							
			local previous_x, previous_y = reaper.ImGui_GetCursorPos(ctx)			

			custom_headers["Header_Param"] = CustomCollapsingHeader(ctx, "Header_Param", header_name, width - 30, 20, 0)
			-- reaper.ImGui_SameLine(ctx)

			-- local x, y = reaper.ImGui_GetCursorPos(ctx)
			reaper.ImGui_SetCursorPos(ctx, width - 29, previous_y)			
			param_lock = DrawLock(28, 20, track_color, 0, param_lock, track, t_last_param.fx, t_last_param.param) -- Lock		

			-- reaper.ImGui_SetCursorPos(ctx, previous_x + 32 - win_padding_x, previous_y + 3)
			-- reaper.ImGui_Text(ctx, header_name)
			local x, y = reaper.ImGui_GetCursorPos(ctx)				
			reaper.ImGui_PopStyleVar(ctx)
			reaper.ImGui_PopFont(ctx)
			-- if header_param then
			if custom_headers["Header_Param"] then	
				header_state_param = 1
				reaper.ImGui_SetCursorPos(ctx, x, y) -- Restore position after Header (instead of using the position of the overlapping text)								
				if reaper.ImGui_BeginChild(ctx, 'FX Param', 0, 105, child_flags, window_flags) then -- Set a fixed size for the FX parameter space
					reaper.ImGui_Dummy(ctx, 0, 0)				
					if param_is_valid == true then -- If there is a valid last touched parameter				

						-- PARAMETER NAME & NATIVE MOD ICONS
						reaper.ImGui_PushFont(ctx, fonts.medium_bold)
						local param_name = t_last_param.param_name

						local param_name_w, param_name_h = reaper.ImGui_CalcTextSize(ctx, param_name)
						local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
						local param_name_hovering = reaper.ImGui_IsMouseHoveringRect(ctx, x, y, x + (width * 0.4), y + param_name_h + 4)

						-- Small ugly GUI tweak
						-- if (param_name_hovering or (t_pm_data.lfo_active and t_pm_data.lfo_active == 1) or (t_pm_data.acs_active and t_pm_data.acs_active == 1)) or (t_pm_data.midi_learn) and (t_pm_data.mod_active == nil) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then 											
						-- 	reaper.ImGui_SetCursorScreenPos(ctx, x, y + 3)
						-- end

						reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 4)

						-- -- Lock icon
						-- DrawIcon(15, 12, track_color, track, t_last_param.fx, t_last_param.param, param_lock, 4) -- Lock
						-- reaper.ImGui_SameLine(ctx)						

						-- Native LFO icon
						if (param_name_hovering or (t_pm_data.lfo_active and t_pm_data.lfo_active == 1)) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then 					
							DrawIcon(15, 12, track_color, track, t_last_param.fx, t_last_param.param, t_pm_data.lfo_active, 1) -- LFO
							reaper.ImGui_SameLine(ctx)						
						end

						-- Native ACS icon
						if (param_name_hovering or t_pm_data.acs_active and t_pm_data.acs_active == 1) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then
							DrawIcon(15, 12, track_color, track, t_last_param.fx, t_last_param.param, t_pm_data.acs_active, 2) -- ACS
							reaper.ImGui_SameLine(ctx)
						end	
						reaper.ImGui_PopStyleVar(ctx, 1)							

						-- MIDI Learn
						local midi_learn_state = t_pm_data.midi_learn and 1 or 0
						if (param_name_hovering or t_pm_data.midi_learn) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then
							DrawIcon(15, 12, track_color, track, t_last_param.fx, t_last_param.param, midi_learn_state, 3) -- MIDI Learn
							reaper.ImGui_SameLine(ctx)
							-- Hack to fix empty offset
							local x, y = reaper.ImGui_GetCursorPos(ctx)
							reaper.ImGui_SetCursorPos(ctx, x - 3, y)
						end	

						-- Parameter name
						local x, y = reaper.ImGui_GetCursorPos(ctx)
						local param_name_clipped = ClipText(param_name, width - x - win_padding_x)
						reaper.ImGui_SameLine(ctx)
						reaper.ImGui_SetCursorPos(ctx, x, y)
						local param_name_color
						if track_color == UI_color then param_name_color = white else param_name_color = track_color end
						reaper.ImGui_TextColored(ctx, param_name_color, param_name_clipped)
						if param_name_clipped ~= param_name then ToolTip(param_name) end

						reaper.ImGui_PopFont(ctx)

						-- FX NAME
						reaper.ImGui_PushFont(ctx, fonts.small)
						local total_fx = reaper.TrackFX_GetCount(track)
						t_last_param.fx_name = t_last_param.fx_name:gsub('——', '-') -- Workaround to replace unsupported "2 long dashes" characters with one small dash (used by Flashmob)							
						t_last_param.fx_name = t_last_param.fx_name:gsub('—', '-') -- Workaround to replace unsupported "1 long dashes" characters with one small dash (used by Flashmob)							

						local fx_name = t_last_param.fx_name .. " (" .. t_last_param.fx + 1 .. "/" .. total_fx .. ")"
						fx_name_clipped = ClipText(fx_name, width - win_padding_x)	

						local x, y = reaper.ImGui_GetCursorPos(ctx)
						local fx_name_w, fx_name_h = reaper.ImGui_CalcTextSize(ctx, fx_name_clipped)

						-- Open FX
						reaper.ImGui_InvisibleButton(ctx, "param_name", fx_name_w, fx_name_h)
						local fx_name_color
						if reaper.ImGui_IsItemHovered(ctx) then				
							fx_name_color = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text(), 1)
							if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Super()) then
								reaper.TrackFX_Show(track, t_last_param.fx, 3) -- In floating window					
							elseif reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
								reaper.TrackFX_Show(track, t_last_param.fx, 1) -- In FXchain
							end						
						else
							fx_name_color = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text(), 0.7)
						end

						-- FX name
						reaper.ImGui_SameLine(ctx)
						reaper.ImGui_SetCursorPos(ctx, x, y)
						reaper.ImGui_TextColored(ctx, fx_name_color, fx_name_clipped)					
						reaper.ImGui_PopFont(ctx)					

						-- PARAMETER VALUE OR BASELINE + MOD RANGE
						reaper.ImGui_PushFont(ctx, fonts.medium_small_bold)
						local min, max, midval			
						last_touched_param_value, min, max, midval = reaper.TrackFX_GetParamEx(track, t_last_param.fx, t_last_param.param)
						last_touched_param_value_raw = last_touched_param_value

						-- Display formatted Baseline and mod range
						local scale_dynamic = 0	
						if (param_link == 1 or t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1) and t_pm_data.mod_active == 1 then
							-- formatted Baseline
							if max ~= 1 then -- If effect is a JSFX
								-- last_touched_param_value = (last_touched_param_value / max) - min -- Useful for JSFX with parameter value range > 1
								last_touched_param_value = t_pm_data.baseline							
								last_touched_param_value = string.format("%.2f", last_touched_param_value)
							else
								rv, last_touched_param_value = reaper.TrackFX_FormatParamValueNormalized(track, t_last_param.fx, t_last_param.param, t_pm_data.baseline, "")												
								last_touched_param_value = ReplaceRareUnicode(last_touched_param_value)							
							end

							-- Special case of plugins not supporting the Cockos VST extension (hard-coded)
							if t_last_param.fx_name_raw:find("Valhalla DSP") then
								local baseline_rounded = string.format("%.2f", t_pm_data.baseline)
								last_touched_param_value = baseline_rounded
							end

							reaper.ImGui_Text(ctx, last_touched_param_value)

							-- mod range text
							local mod_range
							local view_mod_range					

							if param_link == 1 then
								scale_dynamic = t_pm_data.link_scale
								view_mod_range = true
							end					

							-- Override Flashmob or Macros mod range text if hovering above native LFO or ACS
							if t_pm_data.lfo_active == 1 and hover_lfo then
								if t_lfo_params.lfo_dir == 0 then
									scale_dynamic = t_lfo_params.lfo_strength - (t_lfo_params.lfo_strength * 0.5)
								else
									scale_dynamic = t_lfo_params.lfo_strength * t_lfo_params.lfo_dir
								end
								view_mod_range = true
							end
							if t_pm_data.acs_active == 1 and hover_acs then
								if t_acs_params.lfo_dir == 0 then
									scale_dynamic = t_acs_params.acs_strength - (t_acs_params.acs_strength * 0.5)
								else
									scale_dynamic = t_acs_params.acs_strength * t_acs_params.acs_dir
								end
								view_mod_range = true
							end												

							if view_mod_range then
								if max == 1 then
									rv, mod_range = reaper.TrackFX_FormatParamValueNormalized(track, t_last_param.fx, t_last_param.param, t_pm_data.baseline + scale_dynamic, "")
									mod_range = ReplaceRareUnicode(mod_range)

								else -- if FX parameter max is > 1 (often the case with JSFX), skip the parameter value formatting												
									mod_range = t_pm_data.baseline + (scale_dynamic * (max - min))
									if mod_range > max then mod_range = max end
									if mod_range < min then mod_range = min end
									mod_range = string.format("%.2f", mod_range)
								end

								-- Special case of plugins not supporting the Cockos VST extension (hard-coded)
								if t_last_param.fx_name_raw:find("Valhalla DSP") then
									local baseline_mod_rounded = t_pm_data.baseline + scale_dynamic
									if baseline_mod_rounded > max then baseline_mod_rounded = max end
									if baseline_mod_rounded < min then baseline_mod_rounded = min end									
									baseline_mod_rounded = string.format("%.2f", baseline_mod_rounded)
									mod_range = baseline_mod_rounded
								end																

								if mod_range and t_pm_data.mod_active == 1 then

									 -- Draw a small separator line
									reaper.ImGui_SameLine(ctx)	
									local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
									local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
									reaper.ImGui_DrawList_AddLine(draw_list, x, y + 5, x + 10, y + 5, reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 0.8))

									-- Display mod range text
									local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
									reaper.ImGui_SetCursorScreenPos( ctx, x + 17, y) -- Ugly hard-coded
									reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), track_color)
									reaper.ImGui_Text(ctx, mod_range)
									reaper.ImGui_PopStyleColor(ctx, 1)
								end
							end

						-- or Display parameter value
						else
							if max == 1 then -- Format parameter value if effect is not a JSFX
								rv, last_touched_param_value = reaper.TrackFX_FormatParamValueNormalized(track, t_last_param.fx, t_last_param.param, last_touched_param_value, "")
								last_touched_param_value = ReplaceRareUnicode(last_touched_param_value)
							end

							-- Format to 2 digits if last touched parameter is a MACRO
							if t_last_param.fx == mod_container_id and t_last_param.param < 8 then
								last_touched_param_value = string.format("%.2f", last_touched_param_value)
							end
							reaper.ImGui_Text(ctx, last_touched_param_value)
						end			
						reaper.ImGui_PopFont(ctx)			

						-- SLIDERS

						-- Calculate slider mod range 
						if rv_link_scale or rv_baseline or lfo_strength_adjust or acs_strength_adjust then -- If sliders are adjusted, freeze the mod range to its max for a better visualization
							mod_range_slider = t_pm_data.baseline + (scale_dynamic * (max - min)) -- multiply scale by max is important for JSFX with max > 1
						else
							mod_range_slider = last_touched_param_value_raw
						end

						if (param_link > -1 or t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1) and t_pm_data.mod_active == 1 then

							-- Baseline slider
							local view_mod_range_slider = math.max(t_pm_data.link_active, t_pm_data.lfo_active, t_pm_data.acs_active) -- Check if any modulation is active
							rv_baseline, t_pm_data.baseline, mod_range_slider = CustomSlider("Baseline", t_pm_data.baseline, mod_range_slider, min, max, custom_widget_width, 13, midval, true, 1, view_mod_range_slider, track_color)
							if rv_baseline == true then
								reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. t_last_param.param .. ".mod.baseline", t_pm_data.baseline)
							end	

						else -- Parameter real value slider
							last_touched_param_value_raw, min, max, midval = reaper.TrackFX_GetParamEx(track, t_last_param.fx, t_last_param.param)						
							rv_last_touched_param_value_raw, last_touched_param_value_raw = CustomSlider("Value", last_touched_param_value_raw, 0, min, max, custom_widget_width, 13, midval, false, 1, 0, track_color)
							if rv_last_touched_param_value_raw == true then
								reaper.TrackFX_SetParam(track, t_last_param.fx, t_last_param.param, last_touched_param_value_raw)
							end	
						end															

						-- Mod amount slider
						local show_mod_slider
						if reaper.ImGui_IsWindowDocked(ctx) then
							if param_link > -1 then -- If last touched parameter is linked
								show_mod_slider = 1
							end
						else
							show_mod_slider = 1
						end
						if show_mod_slider == 1 then
							if t_pm_data.link_active == nil or t_pm_data.link_active == 0 then		
								reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1.0, 1.0, 1.0, 0.5))
							else									
								reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), reaper.ImGui_ColorConvertDouble4ToU32(1.0, 1.0, 1.0, 1.0))
							end

							if param_link > -1 and param_link < 2 then -- If last touched parameter is linked to the selected Flashmob instance (no matter if its activated or not)
								reaper.ImGui_PushFont(ctx, fonts.medium_bold)
								-- Get linked modulator index (mod or macro)
								local mod_index
								if t_pm_data.link_source_param > 7 then
									mod_index = t_pm_data.link_source_param - 7 -- Hard-coded number of modulators (0-based)
								else
									mod_index = t_pm_data.link_source_param + 1 -- Hard-coded number of macros (0-based)
								end

								-- Display Mod amount text line
								reaper.ImGui_Dummy(ctx, 0, 0)
								reaper.ImGui_BeginGroup(ctx)
								if t_pm_data.link_source_param > 7 then
									reaper.ImGui_Text(ctx, "Mod")
								else
									reaper.ImGui_Text(ctx, "Macro")
								end

								-- Display mod number in a circle
								reaper.ImGui_SameLine(ctx)	
								local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
								local center_x, center_y = reaper.ImGui_GetCursorScreenPos(ctx)

								if t_pm_data.link_source_param > 7 then
									reaper.ImGui_DrawList_AddCircle(draw_list, center_x + 4, center_y + 6, 8, t_color_palette[mod_index], num_segmentsIn, thicknessIn)
								else
									reaper.ImGui_DrawList_AddCircle(draw_list, center_x + 4, center_y + 6, 8, UI_color, num_segmentsIn, thicknessIn)
								end

								if t_pm_data.link_source_param > 7 then
									reaper.ImGui_TextColored(ctx, t_color_palette[mod_index], mod_index)
								else
									reaper.ImGui_TextColored(ctx, UI_color, mod_index)
								end
								reaper.ImGui_SameLine(ctx)	
								reaper.ImGui_Text(ctx, "Amount")
								reaper.ImGui_EndGroup(ctx)
								
								-- reaper.ImGui_PopStyleColor(ctx, 1)
								ToolTip("Left-click: Enable/disable modulation\nAlt-click: Delete modulation")

								-- Logic to active or de-active modulation
								if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
									if t_pm_data.link_active == 0 then	  
										t_pm_data.link_active = 1
										reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. t_last_param.param .. ".plink.active", 1)
									else
										t_pm_data.link_active = 0
										reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. t_last_param.param .. ".plink.active", 0)
										reaper.TrackFX_SetParam(track, t_last_param.fx, t_last_param.param, t_pm_data.baseline)
									end
								end	

								-- Delete modulation
								if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then														
									UnlinkParam(track, t_last_param.fx, t_last_param.param)
								end

								-- Get MOD or MACRO color
								local mod_slider_color
								if t_pm_data.link_source_param > 7 then
									mod_slider_color = t_color_palette[mod_index]
								else
									mod_slider_color = UI_color
								end							

								-- show mod range value text (while adjusting mod amount slider)
								if show_mod_value == true then
									reaper.ImGui_SameLine(ctx)		
									reaper.ImGui_TextColored(ctx, mod_slider_color, string.format('%.1f %%', t_pm_data.link_scale*100))
								end	

								rv_link_scale, t_pm_data.link_scale = CustomSlider("Amount", t_pm_data.link_scale, 0, -1, 1, custom_widget_width, 13, 0, false, t_pm_data.link_active, 0, mod_slider_color)							
								if rv_link_scale then
									reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. t_last_param.param .. ".plink.scale", t_pm_data.link_scale)
									-- rv, mod_range_slider = reaper.TrackFX_FormatParamValueNormalized(track, t_last_param.fx, t_last_param.param, t_pm_data.baseline + t_pm_data.link_scale, "")							
								end

								-- show mod range value text while adjusting mod amount slider
								if reaper.ImGui_IsItemActive(ctx) then
									show_mod_value = true
								else
									show_mod_value = false
								end	
								reaper.ImGui_PopFont(ctx)						
							else
								reaper.ImGui_Dummy(ctx, 0, 0)
								local text_param_link
								if param_link == -1 then
									text_param_link = "No Link Modulation"
								elseif param_link == 2 then
									text_param_link = "Linked to another Flashmob"
								elseif param_link == 3 then
									text_param_link = "Linked to external parameter"
								end
								text_param_link_clipped = ClipText(text_param_link, width - win_padding_x * 2)
								reaper.ImGui_Text(ctx, text_param_link_clipped)
								if text_param_link_clipped ~= text_param_link then ToolTip(text_param_link) end							

								-- Dummy slider (to keep the window size and avoid constant annoying redrawing)
								local rv_dummy, dummy
								if not dummy then dummy = 0 end
								rv_dummy, dummy = CustomSlider("Dummy", dummy, 0, -1, 1, custom_widget_width, 13, 0, false, 0, 0, UI_color)								
							end
							reaper.ImGui_PopStyleColor(ctx, 1)
						end

						reaper.ImGui_Dummy(ctx, 0, 0)
					else
						reaper.ImGui_PushFont(ctx, fonts.medium)
						local text_no_param
						if result == -1 then
							text_no_param = "No last touched parameter detected"
						elseif result == -5 then
							text_no_param = "FX in FX container are not supported yet"					
						elseif result == -2 then
							text_no_param = "Input FX are not supported"
						elseif result == -3 then
							text_no_param = "Take FX are not supported"
						else
							-- text_no_param = "The last touched FX parameter isn't tied to the track"
							text_no_param = "No last touched parameter detected"						
						end
						text_no_param = WrapText(text_no_param, width - win_padding_x * 2)
						reaper.ImGui_Text(ctx, text_no_param)	
						reaper.ImGui_PopFont(ctx)												
					end
				reaper.ImGui_EndChild(ctx)
				end
			else
				header_state_param = 0
			end

			if reload_settings == true then
				if header_state_source == 1 then
					custom_headers["Header_Source"] = true
				else
					custom_headers["Header_Source"] = false
				end	
			end			

			local header_state_source		
			reaper.ImGui_PushFont(ctx, fonts.medium_bold)
			-- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the collapse header
			local header_name_source = "MOD SOURCES"			
			header_name_source = ClipText(header_name_source, width - win_padding_x - 60)			
			local previous_x, previous_y = reaper.ImGui_GetCursorPos(ctx)			
			-- reaper.ImGui_SetCursorPos(ctx, previous_x - win_padding_x, previous_y)

			local header_rounding
			if custom_headers["Header_Source"] == false then header_rounding = 9 else header_rounding = 0 end

			custom_headers["Header_Source"] = CustomCollapsingHeader(ctx, "Header_Source", header_name_source, width - 30, 20, header_rounding)
			-- reaper.ImGui_SameLine(ctx)

			local x, y = reaper.ImGui_GetCursorPos(ctx)
			reaper.ImGui_SetCursorPos(ctx, width - 29, previous_y)			
			DrawAddInstance(28, 20, track_color, track, header_rounding) -- Add Flashmob instance

			-- local header_source = reaper.ImGui_CollapsingHeader(ctx, header_name_source, false, reaper.ImGui_TreeNodeFlags_NoAutoOpenOnLog())			
			-- header_source = reaper.ImGui_CollapsingHeader(ctx, "###Header_Source", false) -- Updating the label (ID) make the header collapsed! So I'm adding the text on top of the header.

			-- reaper.ImGui_SetCursorPos(ctx, previous_x + 32 - win_padding_x, previous_y + 3)
			-- reaper.ImGui_Text(ctx, header_name_source)						
			-- reaper.ImGui_PopStyleVar(ctx)
			-- local x, y = reaper.ImGui_GetCursorPos(ctx)			
			reaper.ImGui_PopFont(ctx)
			if custom_headers["Header_Source"] then									
				header_state_source = 1
				reaper.ImGui_SetCursorPos(ctx, x, y) -- Restore position after Header (instead of using the position of the overlapping text)				
				local visible = reaper.ImGui_BeginChild(ctx, 'Mod', 0, height - y - 8, child_flags, window_flags) -- -32 is hard-coded and should be improved to be dynamic
				if visible then	
					reaper.ImGui_Dummy(ctx, 0, 0)	

					-- Multiple Flashmob instances selector
					if instance_nb > 1 then 
						reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
						-- Left arrow
						if reaper.ImGui_ArrowButton(ctx, '##left', reaper.ImGui_Dir_Left()) then
							mod_container_table_id = mod_container_table_id - 1
							if mod_container_table_id < 1 then mod_container_table_id = #t_flashmob_id end

							mod_container_id = t_flashmob_id[mod_container_table_id]
							reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id, 1)
							reset_plot_lines = true
						end
						local arrow_w = reaper.ImGui_GetItemRectSize(ctx)
						reaper.ImGui_SameLine(ctx)					

						-- Flashmob name
						local total_fx = reaper.TrackFX_GetCount(track)
						local rv_flashmob_name, mod_container_name = reaper.TrackFX_GetFXName(track, mod_container_id)
						if rv_flashmob_name then
							mod_container_name = mod_container_name:gsub('——', '-') -- Workaround to replace unsupported "2 long dashes" characters with one small dash (used by Flashmob)							
							mod_container_name = mod_container_name:gsub('—', '-') -- Workaround to replace unsupported "1 long dashes" characters with one small dash (used by Flashmob)							
							local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx) -- to get the available space (including the potential scrollbar)
							local mod_container_name_clipped = ClipText(mod_container_name, avail_x - arrow_w)
							local mod_container_name_w, mod_container_name_h = reaper.ImGui_CalcTextSize(ctx, mod_container_name_clipped)				

							local x, y = reaper.ImGui_GetCursorPos(ctx)
							local flashmob_name_pos
							if mod_container_name_clipped ~= mod_container_name then -- Center Flashmob name if space is available
								flashmob_name_pos = x + (avail_x - arrow_w - mod_container_name_w - win_padding_x)
							else
								flashmob_name_pos = x + (avail_x - arrow_w - mod_container_name_w - win_padding_x) * 0.5
							end
							-- if flashmob_name_pos <= arrow_w + win_padding_x + 4 then flashmob_name_pos = arrow_w + win_padding_x + 4 end

							reaper.ImGui_SetCursorPos(ctx, flashmob_name_pos, y)
							local flashmob_instance_color
							reaper.ImGui_InvisibleButton(ctx, "flashmob_name", mod_container_name_w, mod_container_name_h)
							if reaper.ImGui_IsItemHovered(ctx) then									
								flashmob_instance_color = BrighterColor2(t_color_palette[mod_container_table_id], 0.2)
								if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
									local retval, retvals_csv = reaper.GetUserInputs("Rename Flashmob Instance", 1, "New Name", mod_container_name)
									if retval then
										local new_name = retvals_csv:match("([^,]+)")
										if new_name ~= "" then
											reaper.TrackFX_SetNamedConfigParm(track, mod_container_id, "renamed_name", new_name)
										end
									end
								end
							else
								flashmob_instance_color = t_color_palette[mod_container_table_id]
							end

							reaper.ImGui_SetCursorPos(ctx, flashmob_name_pos, y)
							reaper.ImGui_PushFont(ctx, fonts.medium_bold)
							reaper.ImGui_TextColored(ctx, flashmob_instance_color, mod_container_name_clipped)
							reaper.ImGui_PopFont(ctx)
							local mod_container_name_num = "(" .. mod_container_table_id .. "/" .. #t_flashmob_id .. ") " ..  mod_container_name -- Add the current flashmob instance index							
							-- if mod_container_name_clipped ~= mod_container_name then ToolTip(mod_container_name_num) end					 
							ToolTip(mod_container_name_num)
						end
						reaper.ImGui_SameLine(ctx)

						-- Right arrow
						local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
						local x, y = reaper.ImGui_GetCursorPos(ctx)
						reaper.ImGui_SetCursorPos(ctx, x + avail_x - arrow_w, y)
						if reaper.ImGui_ArrowButton(ctx, '##right', reaper.ImGui_Dir_Right()) then
							mod_container_table_id = mod_container_table_id + 1
							if mod_container_table_id > #t_flashmob_id then mod_container_table_id = 1 end

							mod_container_id = t_flashmob_id[mod_container_table_id]
							reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id, 1)
							reset_plot_lines = true					
						end	
						reaper.ImGui_PopStyleVar(ctx, 1)
					end

					-- Calcule Mod Graph Data here to be able to switch tabs without interupting the graphs
					for i=1, 6 do
						ModGraphData(track, mod_container_id, i)
					end

					reaper.ImGui_BeginTabBar(ctx, "MyTabs")

					-- Check if the parameter is linked to anything (including link the user made without Flashmob)		
					local param_is_linked_to_anything = t_pm_data.link_active	

					-- Reload last saved tab
					local flags = {0, 0, 0} -- Initialize all flags to 0
					if reload_settings == true and tab_to_load then
						if tab_to_load >= 1 and tab_to_load <= 3 then
							flags[tab_to_load] = reaper.ImGui_TabItemFlags_SetSelected() -- Set the selected flag for the specified tab
						end	
					end
					flag1, flag2, flag3 = table.unpack(flags) -- Unpack the flags back into	


					reaper.ImGui_SetNextItemWidth(ctx, width / 3 - win_padding_x)
					if reaper.ImGui_BeginTabItem(ctx, "Mods", false, flag1) then								
						opened_tab = 1
						for i=1, 6 do
							ModChild(track, mod_container_id, i, t_last_param.fx, t_last_param.param, track_sel_changed, param_is_linked_to_anything)						
						end
						reaper.ImGui_EndTabItem(ctx)
					end

					reaper.ImGui_SetNextItemWidth(ctx, width / 3 - win_padding_x)
					if reaper.ImGui_BeginTabItem(ctx, "Macros", false, flag2) then		
						opened_tab = 2
						for i=1, 8 do
							Macro(track, mod_container_id, i, t_last_param.fx, t_last_param.param, track_sel_changed, param_is_linked_to_anything)
						end		
						reaper.ImGui_EndTabItem(ctx)
					end	
	
					reaper.ImGui_SetNextItemWidth(ctx, width / 3 - win_padding_x)
					local tab_selected = reaper.ImGui_BeginTabItem(ctx, "Native", false, flag3)					
					if t_last_param.param then

						-- Get LFO data for first frame of the tab or if project state change
						if (tab_selected and not previous_tab_selected) or (tab_selected and slower_defer_update) then
							GetNativeLFOData(track, t_last_param.fx, t_last_param.param)
							GetNativeACSData(track, t_last_param.fx, t_last_param.param)
						end
						-- Draw LFO GUI
						if tab_selected then
							DrawMIDILearn(track, t_last_param.fx, t_last_param.param)
							DrawNativeLFO(track, t_last_param.fx, t_last_param.param)
							DrawNativeACS(track, t_last_param.fx, t_last_param.param)													
						end
						previous_tab_selected = tab_selected											
					end								

					if tab_selected then
						opened_tab = 3
						reaper.ImGui_EndTabItem(ctx)
					end				

					-- Save opened tab when tab selection change
					if opened_tab ~= last_opened_tab then
						reaper.SetProjExtState(0, "vf_flashmob", "last_tab", opened_tab)
						last_opened_tab = opened_tab
					end

					reaper.ImGui_EndTabBar(ctx)
					reaper.ImGui_EndChild(ctx)
				end
			else
				header_state_source = 0
			end

			-- Reset previous states when reloading settings
			if reload_settings == true then
				last_opened_tab = opened_tab
				last_header_state_param = header_state_param
				last_header_state_source = header_state_source	
				reload_settings = false				
			end			

			-- Save header states
			if header_state_param ~= last_header_state_param or header_state_source ~= last_header_state_source then				
				local t_headers_settings = {header_state_param, header_state_source}
				headers_settings = table.concat(t_headers_settings, ",")
				reaper.SetProjExtState(0, "vf_flashmob", "header_state", headers_settings)
				last_header_state_param = header_state_param
				last_header_state_source = header_state_source
			end			

		else
			if flashmob_is_invalid == true then
				local invalid_flashmob_text = "Flashmob have been detected but Snap Heap is probably missing"
				invalid_flashmob_text = WrapText(invalid_flashmob_text, width)
				reaper.ImGui_Text(ctx, invalid_flashmob_text)
			else
				reaper.ImGui_Dummy(ctx, 0, 0)
				local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
				local button_width = width * 0.75	
				local button_height = height * 0.35		
				local center_x = x + (width * 0.5) - (button_width * 0.5) - win_padding_x
				local center_y = y + (height * 0.5) - (button_height * 0.5) - win_padding_y * 2
				-- reaper.ImGui_SetCursorPos(ctx, center_x, center_y)
				reaper.ImGui_PushFont(ctx, fonts.medium_bold)
				-- rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, white, track_color, 1)
				-- rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, DarkerColor2(track_color, 0.4), DarkerColor2(track_color, 0.2), 1)
				rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, DarkerColor2(UI_color, 0.25), DarkerColor2(UI_color, 0.1), 1)
				-- rv_addContainer = reaper.ImGui_Button(ctx, "Enable Flashmob", button_width, button_height)
				reaper.ImGui_PopFont(ctx)
				ToolTip("Click to enable FLASHMOB modulations & macros on this track")
				if rv_addContainer then
					reaper.TrackFX_AddByName(track, "../Scripts/VF_ReaScripts Beta/Flashmob/Flashmob.RfxChain", false, 1000)	-- last argument adds an instance if one is not found at the first FX chain index				
					reaper.TrackFX_CopyToTrack(track, reaper.TrackFX_GetCount(track)-1, track, 0, 1) -- Move Flashmob to the first FX chain slot
					reload_settings = true
				end	
			end	
		end

	else
		reaper.ImGui_Text(ctx, "No selected track")
	end

	local popup_open = reaper.ImGui_IsPopupOpen(ctx, "", reaper.ImGui_PopupFlags_AnyPopupId() | reaper.ImGui_PopupFlags_AnyPopupLevel()) -- Check if any popup is opened	
	if reaper.ImGui_IsMouseReleased(ctx, reaper.ImGui_MouseButton_Left() or reaper.ImGui_IsMouseReleased(ctx, reaper.ImGui_MouseButton_Right())) and popup_open == false then
		local reaper_context = reaper.GetCursorContext2(true)
		reaper.SetCursorContext(reaper_context) -- Set focus back to Reaper
	end		

	previous_proj_state = proj_state  
	-- if first_run then first_run = false; reload_settings = false end
	if first_run then first_run = false end
	track_sel_changed = false
	last_proj = current_proj

	-- if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
	-- 	apply = true
	-- 	if close_window == true then
	-- 		open = false
	-- 	end
	-- end

	-- if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) and not reaper.ImGui_IsWindowDocked(ctx) and popup_open == false then
	-- 	open = false
	-- end	
	reaper.ImGui_PopStyleVar(ctx, 2)
end

function Loop()
	reaper.ImGui_PushFont(ctx, fonts.medium)
	reaper.ImGui_SetNextWindowSize(ctx, 480, 320, reaper.ImGui_Cond_FirstUseEver())
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 10, val2In)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(), 3)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), 11)
	
	local main_height = 62
	if rv_flashmob == true then
		if custom_headers["Header_Source"] then 
			main_height = main_height + 512
			if instance_nb > 1 then
				main_height = main_height + 24
			end
		end
		if custom_headers["Header_Param"] then main_height = main_height + 110 end
	else
		main_height = 114
	end

	reaper.ImGui_SetNextWindowSizeConstraints(ctx, 120, main_height, 600, main_height)

	SetTheme()

	local main_window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_TopMost() | reaper.ImGui_WindowFlags_NoFocusOnAppearing() | reaper.ImGui_WindowFlags_NoTitleBar()
	if not reaper.ImGui_IsWindowDocked(ctx) then
		main_window_flags = main_window_flags | reaper.ImGui_WindowFlags_NoScrollbar()
	end

	-- visible, open = reaper.ImGui_Begin(ctx, 'FLASHMOB', true, reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_NoDocking())	
	visible, open = reaper.ImGui_Begin(ctx, 'FLASHMOB', true, main_window_flags)
	if visible then
		Frame()
		reaper.ImGui_End(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx, 13) -- Theme	
	reaper.ImGui_PopStyleVar(ctx, 3)
	reaper.ImGui_PopFont(ctx)	

	if open then
		reaper.defer(Loop)
	end
end

--local start = reaper.time_precise()

-- local profiler = dofile(reaper.GetResourcePath() ..
--   '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
-- reaper.defer = profiler.defer
-- profiler.attachToWorld() -- after all functions have been defined
-- profiler.run()

if Init() == true then
	reaper.defer(Loop)
end

-- local elapsed = reaper.time_precise() - start
-- Print("Script executed in ".. elapsed .." seconds")


