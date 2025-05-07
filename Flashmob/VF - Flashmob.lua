-- @ReaScript Name Flashmob
-- @Screenshot https://imgur.com/i0Azzz1
-- @Author Vincent Fliniaux (Infrabass)
-- @Links https://github.com/Infrabass/Reascripts_Beta
-- @Version 0.5.2
-- @Changelog
--   Fix ACS channel parameter reset to mono after enabling LFO
--   Update last-touched FX param name after MACRO is rename
-- @Provides
--   [main] VF - Flashmob.lua
--   vf_FLASHMOB.jsfx
--   vf_FLASHMOB_GEN.jsfx
--   FXChains/*.RfxChain	
--   Icons/*.png
--   [effect] vf_FLASHMOB.jsfx
--   [effect] vf_FLASHMOB_GEN.jsfx
-- @About 
--   # Powerful modulation system for Reaper based on the mighty Snap Heap from Kilohearts
--   
--   ## Dependencies
--   - Requires ReaImGui
--   - Requires [Snap Heap](https://kilohearts.com/products/snap_heap) from Kilohearts (but MACROS and NATIVE MOD are usable without)


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
	v0.2.3
		+ Small fix	
	v0.2.4
		+ Fix for Nono				
	v0.2.6
		+ Small fix	
	v0.2.7
		+ Use another method to link the script and the FX
		+ Fix macro names
	v0.2.8
		+ fix a bug with the lock feature
		+ Add tag to JSFX
	v0.2.9
		+ fix a crash when showing macro assignations
		+ fix adding another instance of Flashmob of the selected track
	v0.2.10
		+ Add more info for the user in the Snapheap presets
		+ Improve UI
		+ Prepare buttons for future update
		+ If Snapheap is missing, let the user use Flashmob for the MACROS & the NATIVE tabs and only disable the MODS tab
	v0.3
		+ Use graphics instead of drawing shapes for icons
		+ Add a line of buttons above LAST FX PARAM (Overview, Help, Enable Macro Modulation, Lock, Add Instance)
		+ Fix bug: Macro slider modulated by another FLASHMOB move their offset instead of the mod range
		+ By default, tweaking MACROS don't update the last-touched FX param. Add a button to activate the MACROS MODULATION
		+ Set border color to MOD or MACRO linked to last-touched FX param
		+ Add message or color when no mod amount
		+ Improve the error message when trying to map a MACRO to itself	
	v0.3.1
		+ Fix missing pngs
	v0.3.3
		+ Add blinking effect to MOD AMOUNT at 0% to give a better visual feedback
		+ Add tab indicator line for active modulation to give a better visual feedback
		+ In assignation lists, add the possibility open FX by clicking on the FX name
		+ CMD(Mac)/CTRL(PC) + click to open FX in alternate mode (behaviour set in script settings)
		+ When opening MOD assignation lists, auto-enable modulation mapping for MACRO so they can be selected like other FX parameters	
		+ Attempt to fix the Reaper modal window bug on Windows
	v0.3.4
		+ Fixing modal window bug on Windows
	v0.4
		+ Fix modal window bug on Windows
		+ Add default preset feature in setting
		+ Avoid auto-opening Flashmob window when inserting even if the user setting is to "Auto-float newly created FX windows"	
	v0.4.3
		+ Midi learn on MacOS in now fixed
	v0.5
		+ Add assignation lists in MOD and MACRO tabs
		+ Add a powerful OVERVIEW page to see all the modulated parameters on the selected track (magnifying glass icon)
	v0.5.1
		+ Allow user to enable and manage native modulations via Flashmob even if no Flashmob FX is present on track
		+ Add visual feedback for used MODS and used MACROS (colored scope lines and colored macro names)	
	v0.5.2
		+ Fix ACS channel parameter reset to mono after enabling LFO
		+ Update last-touched FX param name after MACRO is rename


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
	if val < 0.1 then val = 0.1 end
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

function OpenURL(url)
	if user_os == "Win" then
		os.execute('start ' .. url)
	elseif user_os == "Mac" then
		os.execute('open ' .. url)
	end
end


------------------------------------------------------------------------------------
-- SECONDARY FUNCTIONS
------------------------------------------------------------------------------------

function GetFlashmobInstances(track, target_fx_name)
	local t_flashmob_id = {}
	local t_flashmob_guid = {}	
	local flashmob_is_invalid
	local fx_count = reaper.TrackFX_GetCount(track)	

	for fx_id = 0, fx_count - 1 do
		local find_Flashmob
		local retval, fx_type = reaper.TrackFX_GetNamedConfigParm(track, fx_id, "fx_type")
		if fx_type == "Container" then
			local first_subfx_id = 0x2000000 + ((0 + 1) * (fx_count + 1)) + (fx_id + 1) -- (index of FX in container + 1) * (fxchain count + 1) + (index of container + 1)		
			local retval, file_name = reaper.TrackFX_GetNamedConfigParm(track, first_subfx_id, "fx_ident")
			if retval and file_name:find(target_fx_name) then
				t_flashmob_id[#t_flashmob_id+1] = fx_id
				t_flashmob_guid[#t_flashmob_guid+1] = reaper.TrackFX_GetFXGUID(track, fx_id)
				find_Flashmob = true
			end
			-- Check if FX inside Flashmob are missing (detected as plugin with 3 parameters: the native wet, bypass and delta)
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

	if t_flashmob_id[1] == nil then
		return false, t_flashmob_id, t_flashmob_guid, flashmob_is_invalid  -- Not found
	else
		return true, t_flashmob_id, t_flashmob_guid, flashmob_is_invalid
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
	local result, store_previous_param, new_param_guid_hack
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
						new_param_guid_hack = ((track_id+4)*-66) * (fx+13) * ((param+39)*-73) + track_id -- Pseudo random gen number to check if last touched param changed (quicker than using the FX GUID)	

						-- Check if last-touched FX param is a Flashmob parameter
						local flashmob_inst
						for i=1, #t_flashmob_id do
							if fx == t_flashmob_id[i] then
								flashmob_inst = true
								break
							end
						end						
						
						if new_param_guid_hack ~= last_param_guid_hack or force_update then
							-- Bingo, a new parameter have been detected							

							if flashmob_inst and param <= 7 and macro_mod_enable == 0 then -- If last-touched FX param is a macro of any Flashmob on the track
								if t_last_param.param then
									-- Set previous last-touched FX param as the current last-touched FX param
									local previous_param_val = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
									reaper.TrackFX_SetParam(track, t_last_param.fx, t_last_param.param, previous_param_val) -- To set as last touched param
									rv, track_id, itemidx, takeidx, fx, param = reaper.GetTouchedOrFocusedFX(0) -- Get last touched FX parameter										
									result = 1
								else
									result = -1
								end
							else
								-- Check if previous touched FX param is a macro of any Flashmob of the track
								if t_last_param.param then
									local previous_param_is_any_macro
									for i=1, #t_flashmob_id do										
										if t_last_param.fx == t_flashmob_id[i] then																		
											if t_last_param.param <= 7 then
												previous_param_is_any_macro = true
												break
											end
										end
									end

									-- If previous touched param wasn't a MACRO, store it to recall it when disabling "modulation mapping of macro"
									if rv_flashmob == true and macro_mod_enable == 1 and fx == mod_container_id and param <= 7 and previous_param_is_any_macro == nil then
										store_previous_param = true
									end
								end
								result = 1
							end	
							force_update = nil						
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
		t_previous_param = {}
		t_pm_data = {}
		t_pm_lfo = {}
		t_pm_acs = {}				
		last_param_guid_hack = nil				
		return false, result

	else
		if store_previous_param then
			t_previous_param = {          
				param = t_last_param.param,
				param_name = t_last_param.param_name,
				fx = t_last_param.fx,
				fx_name = t_last_param.fx_name,
				fx_name_raw = t_last_param.fx_name_raw
			} 			
		end

		if result == 1 then
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
		end

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
	-- if param_is_linked_to_anything == 1 then	
	-- 	local user_input_overwrite = reaper.ShowMessageBox("The parameter is already mapped.\nAre you sure you want to overwrite the mapping?", "OVERWRITE MAPPING?", 4)
	-- 	if user_input_overwrite == 7 then -- NO
	-- 		return
	-- 	end
	-- end
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.effect", fx)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.param", param)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.active", 1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.offset", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.scale", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.active", 1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.baseline", new_baseline)

	if show_track_control == true then
		if setting_track_control == 1 then
			ShowInTrackControl(track, touched_fx, touched_param)
		end
	end

	-- if param_lock == 1 then
		GetPMData(track, touched_fx, touched_param)
		CheckIfModIsUsed(track, mod_container_id) -- To set plotline color
		CheckIfMacroIsUsed(track, mod_container_id) -- To set macro slider color
	-- end
end

function UnlinkParam(track, touched_fx, touched_param)
	-- local user_input_overwrite = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
	-- if user_input_overwrite == 7 then -- NO
	-- 	return
	-- end	

	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.effect", -1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.param", -1)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.active", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.offset", 0)
	reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".plink.scale", 0)

	if t_pm_data.lfo_active == 0 and t_pm_data.acs_active == 0 then
		-- reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.active", 0)
		reaper.TrackFX_SetNamedConfigParm(track, touched_fx, "param." .. touched_param .. ".mod.baseline", 0)
		if setting_track_control == 1 then
			RemoveTrackControl(track, touched_fx, touched_param)
		end
	end
	CheckIfModIsUsed(track, mod_container_id) -- To set plotline color
	CheckIfMacroIsUsed(track, mod_container_id) -- To set macro slider color
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
	local total_fx = reaper.TrackFX_GetCount(track)	
	for i=0, total_fx -1 do
		for j=0, reaper.TrackFX_GetNumParams(track, i) -1 do
			local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.active") 			
			local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.effect") 
			local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.param")
			link_active = tonumber(link_active)
			link_source_fx = tonumber(link_source_fx)
			link_source_param = tonumber(link_source_param)

			if link_active == 1 and link_source_fx == fx and link_source_param == param then
				local _, fx_name = reaper.TrackFX_GetFXName(track, i)
				local fx_name_raw = fx_name
				fx_name = fx_name:gsub('——', '-') -- Workaround to replace "2 long dashes" characters with one small dash (used by Flashmob)
				fx_name = fx_name:gsub('—', '-') -- Workaround to replace "1 long dashes" characters with one small dash (used by Flashmob)
				fx_name = SimplifyPluginNames(fx_name)
				fx_name = fx_name .. " (" .. i + 1 .. "/" .. total_fx .. ")"
				local _, param_name = reaper.TrackFX_GetParamName(track, i, j)
				t_assignations[#t_assignations+1] = {fx_id = i, param_id = j, fx_name = fx_name, fx_name_raw = fx_name_raw, param_name = param_name}
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
			if setting_track_control == 1 then
				ShowInTrackControl(track, fx, param) -- Show in Track control					
			end
		else
			new_baseline = 0
			reaper.TrackFX_SetParam(track, fx, param, t_pm_data.baseline)
			if setting_track_control == 1 then
				RemoveTrackControl(track, fx, param) -- Remove from Track control
			end
		end
	end	

	if state == 1 then
		-- Set custom default values if native default values are detected
		if t_lfo_params.lfo_active == 0 and t_lfo_params.lfo_shape == 0 and t_lfo_params.lfo_speed == 1 and t_lfo_params.lfo_strength == 1 and t_lfo_params.lfo_dir == 1 and t_lfo_params.lfo_phase == 0 and t_lfo_params.lfo_temposync == 0 and t_lfo_params.lfo_free == 0 then
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.strength", 0.25)
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.dir", 0)
		end

		reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".mod.active", 1) -- active PM
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
			if setting_track_control == 1 then
				ShowInTrackControl(track, fx, param) -- Show in Track control
			end

		else
			new_baseline = 0
			reaper.TrackFX_SetParam(track, fx, param, t_pm_data.baseline)
			if setting_track_control == 1 then
				RemoveTrackControl(track, fx, param) -- Remove from Track control
			end
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

		reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.stereo", 1) -- Set to stereo to counteract a Reaper bug: When ACS is bypassed, enabling LFO reset ACS Stereo to 0 (mono channel)

		reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".mod.active", 1)	-- Active PM
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

function GetSidechain(track, fx)
	local inL, high32 = reaper.TrackFX_GetPinMappings(track, fx, 0, 0)
	local inR, high32 = reaper.TrackFX_GetPinMappings(track, fx, 0, 1)
	local outL, high32 = reaper.TrackFX_GetPinMappings(track, fx, 1, 0)
	local outR, high32 = reaper.TrackFX_GetPinMappings(track, fx, 1, 1)

	if inL == 1 and inR == 2 then
		setting_sidechain = 0
	elseif inL == 4 and inR == 8 then
		setting_sidechain = 1
	else -- if routing is invalid, set to 1/2
		setting_sidechain = 0
		reaper.TrackFX_SetPinMappings(track, fx, 0, 0, 1, 0)
		reaper.TrackFX_SetPinMappings(track, fx, 0, 1, 2, 0)
		reaper.TrackFX_SetPinMappings(track, fx, 1, 0, 1, 0)
		reaper.TrackFX_SetPinMappings(track, fx, 1, 1, 2, 0)		
	end
end

function SetFlashmobRouting(track, fx, setting_sidechain)
	if setting_sidechain == 0 then
		in_L = 1
		in_R = 2
		out_L = 1
		out_R = 2
	else
		in_L = 4
		in_R = 8
		out_L = 4
		out_R = 8
	end		

	reaper.TrackFX_SetPinMappings(track, fx, 0, 0, in_L, 0)
	reaper.TrackFX_SetPinMappings(track, fx, 0, 1, in_R, 0)
	reaper.TrackFX_SetPinMappings(track, fx, 1, 0, out_L, 0)
	reaper.TrackFX_SetPinMappings(track, fx, 1, 1, out_R, 0)
end

function ToggleSidechain(track, fx)
	local ch_nb = reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")
	local inL, high32 = reaper.TrackFX_GetPinMappings(track, fx, 0, 0)
	local inR, high32 = reaper.TrackFX_GetPinMappings(track, fx, 0, 1)
	local outL, high32 = reaper.TrackFX_GetPinMappings(track, fx, 1, 0)
	local outR, high32 = reaper.TrackFX_GetPinMappings(track, fx, 1, 1)

	if inL ~= 4 and inR ~= 8 then
		if ch_nb < 4 then
			reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 4)
		end
		in_L = 4
		in_R = 8
		out_L = 4
		out_R = 8			
	else	
		in_L = 1
		in_R = 2
		out_L = 1
		out_R = 2	
	end		

	reaper.TrackFX_SetPinMappings(track, fx, 0, 0, in_L, 0)
	reaper.TrackFX_SetPinMappings(track, fx, 0, 1, in_R, 0)
	reaper.TrackFX_SetPinMappings(track, fx, 1, 0, out_L, 0)
	reaper.TrackFX_SetPinMappings(track, fx, 1, 1, out_R, 0) 		
end

function StartModalWorkaround(id)
	modal_popup_id = id
	modal_popup_prepare = true
end

function ResetModalWorkaroundVariables()
	modal_popup_prepare = nil
	wait1Frame = nil
	modal_popup = nil
	modal_popup_id = ""
end

function GetFXChainsList()
	local t_fxchains = {}
	local path = script_path .. "FXChains"
	-- if user_os == "Mac" then
	-- 	path = script_path .. "FXChains"
	-- elseif user_os == "Win" then

	-- end

	local file = ""	
	local i = 0
	while file do
		file = reaper.EnumerateFiles(path, i)
		if file then 
			if file:match(".*%.RfxChain$") then
				t_fxchains[#t_fxchains+1] = file:gsub("%.RfxChain$", "")
			end
		end
		i = i + 1
	end
	return t_fxchains
end

function AddFlashmobInstance(track, first_slot)
	local openFloating_setting = reaper.SNM_GetIntConfigVar("fxfloat_focus", -666) -- Save the original user setting to open or not floating window when adding new FX
	reaper.SNM_SetIntConfigVar("fxfloat_focus", openFloating_setting&(~4)) -- Temporarly disable the user setting

	mod_container_id = reaper.TrackFX_GetCount(track)

	reaper.TrackFX_AddByName(track, "../Scripts/VF_ReaScripts Beta/Flashmob/FXChains/" .. default_preset  .. ".RfxChain", false, 1024)	-- last argument adds an instance if one is not found at the first FX chain index				
	if first_slot and first_slot == 1 then
		reaper.TrackFX_CopyToTrack(track, reaper.TrackFX_GetCount(track)-1, track, 0, 1) -- Move Flashmob to the first FX chain slot
		mod_container_id = 0
	end
	reaper.SNM_SetIntConfigVar("fxfloat_focus", openFloating_setting) -- Restore user setting						

	CheckIfModIsUsed(track, mod_container_id)
	CheckIfMacroIsUsed(track, mod_container_id)
end	

function OpenSnapheap(track, fx, index)
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

function GetOverview(track)
	local t_overview = {}
	local total_fx = reaper.TrackFX_GetCount(track)	
	for i=0, total_fx -1 do
		-- t_overview[#t_overview+1] = {fx_id = i, fx_name = fx_name}
		for j=0, reaper.TrackFX_GetNumParams(track, i) -1 do
			local _, mod_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".mod.active") 			
			local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.active") 			
			local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.effect") 
			local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.param")
			local _, lfo_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".lfo.active")
			local _, acs_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".acs.active")
			local _, midi_learn = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".learn.midi1")
			mod_active = tonumber(mod_active)			
			link_active = tonumber(link_active)
			link_source_fx = tonumber(link_source_fx)
			link_source_param = tonumber(link_source_param)
			lfo_active = tonumber(lfo_active)
			acs_active = tonumber(acs_active)
			midi_learn = tonumber(midi_learn)

			-- if link_active == 1 or lfo_active == 1 or acs_active == 1 then
			if mod_active == 1 then
				local _, fx_name = reaper.TrackFX_GetFXName(track, i)
				local fx_name_raw = fx_name
				fx_name = fx_name:gsub('——', '-') -- Workaround to replace "2 long dashes" characters with one small dash (used by Flashmob)
				fx_name = fx_name:gsub('—', '-') -- Workaround to replace "1 long dashes" characters with one small dash (used by Flashmob)
				fx_name = SimplifyPluginNames(fx_name)
				fx_name = fx_name .. " (" .. i + 1 .. "/" .. total_fx .. ")"
				local _, param_name = reaper.TrackFX_GetParamName(track, i, j)
				t_overview[#t_overview+1] = {fx_id = i, param_id = j, fx_name = fx_name, fx_name_raw = fx_name_raw, param_name = param_name, link_active = link_active, lfo_active = lfo_active, acs_active = acs_active, midi_learn = midi_learn}
			end
		end
	end
	return t_overview
end

function CheckIfModIsUsed(track, fx)
	modUsed = {modUsed1 = nil, modUsed2 = nil, modUsed3 = nil, modUsed4 = nil, modUsed5 = nil, modUsed6 = nil}
	local total_fx = reaper.TrackFX_GetCount(track)	
	for i=0, total_fx -1 do
		-- t_overview[#t_overview+1] = {fx_id = i, fx_name = fx_name}
		for j=0, reaper.TrackFX_GetNumParams(track, i) -1 do
			local _, mod_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".mod.active") 			
			local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.active") 	
			if mod_active == "1" and link_active == "1" then

				local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.effect") 
				local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.param")
				link_source_fx = tonumber(link_source_fx)
				link_source_param = tonumber(link_source_param)

				if link_source_fx == fx and link_source_param > 7 then
					for h=1, 6 do
						if link_source_param == 7 + h then
							modUsed["modUsed" .. tostring(h)] = true
							break
						end
					end
				end
			end
		end
	end
end

function CheckIfMacroIsUsed(track, fx)
	macroUsed = {macroUsed1 = nil, macroUsed2 = nil, macroUsed3 = nil, macroUsed4 = nil, macroUsed5 = nil, macroUsed6 = nil}
	local total_fx = reaper.TrackFX_GetCount(track)	
	for i=0, total_fx -1 do
		-- t_overview[#t_overview+1] = {fx_id = i, fx_name = fx_name}
		for j=0, reaper.TrackFX_GetNumParams(track, i) -1 do
			local _, mod_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".mod.active") 			
			local _, link_active = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.active") 	
			if mod_active == "1" and link_active == "1" then

				local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.effect") 
				local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, i, "param." .. j .. ".plink.param")
				link_source_fx = tonumber(link_source_fx)
				link_source_param = tonumber(link_source_param)

				if link_source_fx == fx and link_source_param < 8 then
					for h=0, 7 do
						if link_source_param == h then
							macroUsed["macroUsed" .. tostring(h+1)] = true
							break
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------
-- GUI
------------------------------------------------------------------------------------

function ToolTip(text, persistent)
	if (setting_tooltip == 1 or persistent) and reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal() | reaper.ImGui_HoveredFlags_AllowWhenDisabled()) then
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

function CustomSlider(label, valueA, valueB, min, max, width, height, default, mod_indicator, active, active_mod_range, color, valueA_fill)
	local width = width or 100
	local height = height or 12
	if width < 1 then width = 1 end
	if height < 1 then height = 1 end

	if valueB < min then valueB = min end
	if valueB > max then valueB = max end

	local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
	
	-- Calculate position
	local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
	
	-- Calculate normalized values
	local range = max - min
	local normalizedA = (valueA - min) / range
	local normalizedB = (valueB - min) / range
	
	-- Colors
	local bg_color
	if active == 1 then  
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
	if valueA_fill == 1 then
		reaper.ImGui_DrawList_AddRectFilled(
			draw_list,
			indicator_center - indicator_width * 0.5,
			y,
			indicator_center + indicator_width * 0.5,
			y + height,
			center_color
		)  
	else
		reaper.ImGui_DrawList_AddRectFilled(
			draw_list,
			indicator_center - indicator_width * 0.5,
			y,
			indicator_center + indicator_width * 0.5,
			y + height,
			DarkerColor2(center_color, 0.5)

			-- indicator_center - indicator_width/3,
			-- y + height - 1,
			-- indicator_center + indicator_width/3,
			-- y + height - 4,
			-- center_color
		) 
	end  

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

	-- Draw range from 0 to valueA using a brighter color id valueA_fill == 1
	if valueA_fill == 1 then
		local indicator_a_x = x + width * 0.5
		local indicator_b_x = x + (width * normalizedA)
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
	
	-- Small UI tweak to align the interactive button with the slider
	local x1, y1 = reaper.ImGui_GetCursorScreenPos(ctx)
	reaper.ImGui_SetCursorScreenPos(ctx, x1, y1 + 1)
 
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 2)
	reaper.ImGui_InvisibleButton(ctx, label, width, height)
	reaper.ImGui_PopStyleVar(ctx, 1)
	
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

	local mod_button_color = t_color_palette[index]
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)

	-- Set border color and thickness
	local vertical_line_border_size = 1
	if t_pm_data.link_source_fx and (t_pm_data.link_source_fx + (t_pm_data.link_source_param * 0.1) == fx + (mod_param_id * 0.1)) then -- If last-touched FX param is linked to this MOD	
		mod_border_color = t_color_palette[index]
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 2)
		vertical_line_border_size = 2
	else
		mod_border_color = DarkerColor2(white, 0.5)
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)
	end

	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), mod_border_color)	
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), mod_button_color)
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), DarkerColor(mod_button_color))
	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), mod_button_color)	

	if not _G["modChild_height" .. index] then _G["modChild_height" .. index] = 76 end
	if _G["modList" .. index] == 1 and slower_defer_update then 
		t_assignations = GetAssignations(track, fx, mod_param_id) -- Need to optimize this potentially intense function
		if #t_assignations == 0 then
			_G["modChild_height" .. index] = 76 + 28
		else
			_G["modChild_height" .. index] = 76 + 12 + 40 * #t_assignations
		end
	elseif _G["modList" .. index] == 0 then
		_G["modChild_height" .. index] = 76
	end

	local visible = reaper.ImGui_BeginChild(ctx, 'Mod_Child' .. str_index, 0, _G["modChild_height" .. index], reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then

		-- MAP button		
		-- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), t_color_palette[index])
		-- reaper.ImGui_BeginGroup(ctx)

		-- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), BrighterColor(t_color_palette[index]))
		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		local link_confirmed
		if reaper.ImGui_Button(ctx, "MOD\n   " .. index, 40, 60) then
			if t_last_param.param then	

				-- -- Keep parameter current value if no native modulation is active
				-- local new_baseline
				-- if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
				-- 	new_baseline = t_pm_data.baseline
				-- else				
				-- 	new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
				-- end

				if param_is_linked_to_anything == 1 then
					if user_os == "Win" then
						StartModalWorkaround("mod_overwrite" .. str_index)
					else	
						local _, link_source_param_name = reaper.TrackFX_GetParamName(track, t_pm_data.link_source_fx, t_pm_data.link_source_param)
						local user_input_overwrite = reaper.ShowMessageBox("The parameter is already mapped to\n[" .. link_source_param_name ..  "].\nAre you sure you want to overwrite the mapping?", "OVERWRITE MAPPING?", 4)
						if user_input_overwrite == 6 then -- YES
							link_confirmed = true
						end
					end
				else
					link_confirmed = true
				end

				-- LinkParam(track, touched_fx, fx, touched_param, mod_param_id, new_baseline, param_is_linked_to_anything, true)
			else
				if user_os == "Win" then
					StartModalWorkaround("map_no_param")
				else	
					reaper.ShowMessageBox("\nYou must adjust an FX parameter before mapping to this modulator", "MAPPING FAILED", 0)
				end				
			end
		end			

		if user_os == "Win" and modal_popup_id == "mod_overwrite" .. str_index and modal_popup == true then
			local _, link_source_param_name = reaper.TrackFX_GetParamName(track, t_pm_data.link_source_fx, t_pm_data.link_source_param)
			local user_input_overwrite = reaper.ShowMessageBox("The parameter is already mapped to\n[" .. link_source_param_name ..  "].\nAre you sure you want to overwrite the mapping?", "OVERWRITE MAPPING?", 4)
			if user_input_overwrite == 6 then -- YES
				link_confirmed = true
			end			
			ResetModalWorkaroundVariables()
		end	

		if link_confirmed == true then
			-- Keep parameter current value if no native modulation is active
			local new_baseline
			if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
				new_baseline = t_pm_data.baseline
			else				
				new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
			end

			LinkParam(track, touched_fx, fx, touched_param, mod_param_id, new_baseline, param_is_linked_to_anything, true)
		end		

		-- reaper.ImGui_PopFont(ctx)				

		if param_is_linked_to_anything == 1 then		
			ToolTip("Remap [" .. t_last_param.param_name .. "] to MOD " .. index)	
		else
			if t_last_param.param then 
				ToolTip("Map [" .. t_last_param.param_name .. "] to MOD " .. index)
			end
		end

		-- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
		-- if reaper.ImGui_Button(ctx, "List", 40, 16) then
		-- 	if not _G["modList" .. index] then _G["modList" .. index] = 0 end
		-- 	if not _G["modPopup" .. index] then _G["modPopup" .. index] = 0 end
		-- 	-- Close all the other mod assign list before opening this one
		-- 	for i=1, 6 do
		-- 		if i ~= index then
		-- 			_G["modList" .. i] = 0
		-- 			_G["modPopup" .. i] = 0
		-- 		end
		-- 	end			
		-- 	_G["modList" .. index] = 1 - _G["modList" .. index]
		-- 	_G["modPopup" .. index] = 1 - _G["modPopup" .. index]			
		-- end
		-- reaper.ImGui_PopStyleVar(ctx, 1)

		-- reaper.ImGui_EndGroup(ctx)

		reaper.ImGui_PopFont(ctx)		
		reaper.ImGui_PopStyleColor(ctx, 1)
		-- reaper.ImGui_PopStyleVar(ctx, 1)
		reaper.ImGui_SameLine(ctx)

		-- Draw vertical separation line
		local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
		local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
		reaper.ImGui_DrawList_AddLine(draw_list, x - 2, y - win_padding_y, x - 2, y + 76 - win_padding_y, mod_border_color, vertical_line_border_size)
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

		-- local mod_used
		-- if slower_defer_update then
		-- 	mod_used = CheckIfModIsUsed(track, mod_container_id, index + 7)
		-- end

		if modUsed["modUsed" .. str_index] then
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLines(), BrighterColor(t_color_palette[index]))
		else
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLines(), UI_color)
		end

		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLinesHovered(), UI_color) -- Disable plot line hovering default red color

		local x, y = reaper.ImGui_GetCursorPos(ctx)
		local width, height = reaper.ImGui_GetWindowSize(ctx) 
		reaper.ImGui_SetNextItemWidth(ctx, width - x - win_padding_x)
		reaper.ImGui_PlotLines(ctx, '##Lines' .. str_index, _G["plots" .. str_index].data, _G["plots" .. str_index].offset - 1, overlay, 0, 1.0, 0, 60.0)
		local data_str = tostring(mod_val)		
		data_str = string.format("%.2f", data_str)
		ToolTipPlotLines(data_str) -- Override the default plotlines tooltip (that have a instantaneous hard-coded tooltip)
		ToolTip("Left-click: Open/close Snapheap\nRight-click: Show assignations")

		reaper.ImGui_PopStyleColor(ctx, 2)

		-- Open Snap Heap
		if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
			OpenSnapheap(track, fx, index)
		end

		-- Open assignations list
		if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Right()) then
			if not _G["modList" .. index] then _G["modList" .. index] = 0 end
			if not _G["modPopup" .. index] then _G["modPopup" .. index] = 0 end
			-- Close all the other mod assign list before opening this one
			for i=1, 6 do
				if i ~= index then
					_G["modList" .. i] = 0
					_G["modPopup" .. i] = 0
				end
			end			
			_G["modList" .. index] = 1 - _G["modList" .. index]
			_G["modPopup" .. index] = 1 - _G["modPopup" .. index]
		end

		if _G["modList" .. index] == 1 then
			local popup_width, popup_height = reaper.ImGui_GetWindowSize(ctx)
			local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)
			reaper.ImGui_DrawList_AddLine(draw_list, screen_x - win_padding_x, screen_y + 4, screen_x + width - win_padding_x, screen_y + 4, mod_border_color, vertical_line_border_size)

			-- if slower_defer_update then
				t_assignations = GetAssignations(track, fx, mod_param_id) -- Need to optimize this potentially intense function
			-- end

			overview_baseline = nil
			overview_scale = nil


			if #t_assignations == 0 then
				reaper.ImGui_Dummy(ctx, 0, 7)
				reaper.ImGui_Text(ctx, "No assignation")
			else
				for i=1, #t_assignations do
					if i == 1 then reaper.ImGui_Dummy(ctx, 0, 6) end
					-- Use a dummy invisible button to detect hover first
					-- local assignation_color = DarkerColor(t_color_palette[index], 4)
					local assignation_color = DarkerColor2(t_color_palette[index], 0.1)
					local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].param_name)
					local x, y = reaper.ImGui_GetCursorPos( ctx )
					-- reaper.ImGui_SetCursorPos(ctx, x, y + 8)
					reaper.ImGui_InvisibleButton(ctx, "hover_area", text_size_x, text_size_y)
					ToolTip("Alt-click: Delete assignation")

					if reaper.ImGui_IsItemHovered(ctx) then
						-- assignation_color = BrighterColor(t_color_palette[index], 1)
						assignation_color = BrighterColor2(t_color_palette[index], 0.3)
					end

					-- Set as last touched parameter
					if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
						local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
					end		

					-- Delete modulation
					local unlink_confirmed					
					if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then																				
						local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param

						if user_os == "Win" then
							StartModalWorkaround("remove_mapping_mod_assign_list" .. i)
						else	
							local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
							if user_input_remove_mapping == 6 then -- YES
								unlink_confirmed = true
							end	
						end					
						-- UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
					end				

					if user_os == "Win" and modal_popup_id == "remove_mapping_mod_assign_list" .. i and modal_popup == true then
						local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
						if user_input_remove_mapping == 6 then -- YES
							unlink_confirmed = true
						end			
						ResetModalWorkaroundVariables()
					end										

					if unlink_confirmed == true then									
						UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
					end


					-- Draw the param name with the determined color
					reaper.ImGui_SameLine(ctx)
					reaper.ImGui_SetCursorPos(ctx, x, y)			
					reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].param_name)

					-- Draw FX name if this is a new FX
					if i == 1 or t_assignations[i].fx_id ~= t_assignations[i-1].fx_id then
						reaper.ImGui_SameLine(ctx)
						local assignation_color = white
						local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].fx_name)
						local x, y = reaper.ImGui_GetCursorPos( ctx )
						reaper.ImGui_InvisibleButton(ctx, "hover_area_fx", text_size_x, text_size_y)

						if reaper.ImGui_IsItemHovered(ctx) then
							assignation_color = full_white
						end

						-- Open FX
						if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
							if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
								reaper.TrackFX_Show(track, t_assignations[i].fx_id, 3) -- In floating window					
							else
								reaper.TrackFX_Show(track, t_assignations[i].fx_id, 1) -- In FXchain	
							end
						end					

						-- Draw the fx name
						reaper.ImGui_SameLine(ctx)
						reaper.ImGui_PushFont(ctx, fonts.small)
						reaper.ImGui_SetCursorPos(ctx, x, y + 3)
						local width_for_fxName = reaper.ImGui_GetContentRegionAvail(ctx)
						local fx_name_clipped = ClipText(t_assignations[i].fx_name, width_for_fxName)
						reaper.ImGui_TextColored(ctx, assignation_color, fx_name_clipped)
						if fx_name_clipped ~= t_assignations[i].fx_name then ToolTip(t_assignations[i].fx_name) end
						reaper.ImGui_PopFont(ctx)
					end

					-- Show baseline and mod amount sliders
					reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), t_color_palette[index])
					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), t_color_palette[index])

					local val, min, max = reaper.TrackFX_GetParamEx(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					local _, offset = reaper.TrackFX_GetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".mod.baseline")
					local offset_formatted

					if max ~= 1 then -- If effect is a JSFX
						-- last_touched_param_value = (last_touched_param_value / max) - min -- Useful for JSFX with parameter value range > 1
						offset_formatted = offset
						offset_formatted = string.format("%.2f", offset_formatted)
					else
						rv, offset_formatted = reaper.TrackFX_FormatParamValueNormalized(track, t_assignations[i].fx_id, t_assignations[i].param_id, offset, "")												
						offset_formatted = ReplaceRareUnicode(offset_formatted)							
					end

					offset_formatted = offset_formatted:gsub("%%", "%%%%")

					-- Special case of plugins not supporting the Cockos VST extension (hard-coded)
					if t_assignations[i].fx_name_raw:find("Valhalla DSP") then
						local baseline_rounded = string.format("%.2f", offset)
						offset_formatted = baseline_rounded
					end


					reaper.ImGui_SetNextItemWidth(ctx, popup_width * 0.5 - (win_padding_x * 2))
					local rv_offset, offset = reaper.ImGui_SliderDouble(ctx, "##offset" .. i, offset, min, max, offset_formatted)
					-- local rv_offset, offset = reaper.ImGui_SliderDouble(ctx, "##offset" .. i, offset, min, max)
					if rv_offset then

						-- active as last-touched FX param
						local val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, val)

						reaper.TrackFX_SetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".mod.baseline", offset)
					end

					-- show mod range
					if reaper.ImGui_IsItemActive(ctx) then
						overview_baseline = 1
					end	

					reaper.ImGui_SameLine(ctx)

					local _, amount = reaper.TrackFX_GetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".plink.scale")
					local amount_formatted = string.format('%.1f %%%%', amount * 100)

					reaper.ImGui_SetNextItemWidth(ctx, popup_width * 0.5 - (win_padding_x * 2))
					local rv_amount, amount = reaper.ImGui_SliderDouble(ctx, "##amount" .. i, amount, -1, 1, amount_formatted)
					if rv_amount then

						show_mod_value = true

						-- active as last-touched FX param
						local val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, val)

						reaper.TrackFX_SetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".plink.scale", amount)
					end	

					-- show mod range
					if reaper.ImGui_IsItemActive(ctx) then
						overview_scale = 1
					end						

					-- Update data
					if rv_offset or rv_amount then
						GetLastTouchedFXParam(track)
						GetPMData(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					end					

					reaper.ImGui_PopStyleVar(ctx, 1)
					reaper.ImGui_PopStyleColor(ctx, 2)
				end
			end
		end
	
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx, 4)
	reaper.ImGui_PopStyleVar(ctx, 2)
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

	-- Check if last-touched FX param is a Flashmob parameter
	local flashmob_inst
	for i=1, #t_flashmob_id do
		if link_source_fx == t_flashmob_id[i] then
			flashmob_inst = true
			break
		end
	end

	if link_active == 1 and flashmob_inst then -- if the macro is linked to a Flashmob container parameter...
		macro_is_linked = 1
	end		

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	-- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))

	-- Set border color and thickness
	local vertical_line_border_size = 1
	if t_pm_data.link_source_fx and (t_pm_data.link_source_fx + (t_pm_data.link_source_param * 0.1) == fx + (macro_param_id * 0.1)) then -- If last-touched FX param is linked to this MOD	
		mod_border_color = BrighterColor2(t_color_palette[mod_container_table_id], 0.4)
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 2)
		vertical_line_border_size = 2
	else
		mod_border_color = DarkerColor2(white, 0.5)
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)
	end


	reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), mod_border_color)

	if macroUsed["macroUsed" .. str_index] then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor2(t_color_palette[mod_container_table_id], 0.4))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), DarkerColor2(t_color_palette[mod_container_table_id], 0.3))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), t_color_palette[mod_container_table_id])		
	else
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor2(UI_color, 0.4))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), DarkerColor2(UI_color, 0.4))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), UI_color)		
	end	

	if not _G["macroChild_height" .. index] then _G["macroChild_height" .. index] = 40 + win_padding_y * 2 end
	if _G["macroList" .. index] == 1 and slower_defer_update then 
		t_assignations = GetAssignations(track, fx, macro_param_id) -- Need to optimize this potentially intense function
		if #t_assignations == 0 then
			_G["macroChild_height" .. index] = 40 + win_padding_y * 2 + 28
		else
			_G["macroChild_height" .. index] = 40 + win_padding_y * 2 + 18 + 39 * #t_assignations
		end
	elseif _G["macroList" .. index] == 0 then
		_G["macroChild_height" .. index] = 40 + win_padding_y * 2
	end

	local visible = reaper.ImGui_BeginChild(ctx, 'Macro_Child' .. str_index, 0, _G["macroChild_height" .. index], reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then

		local x, y = reaper.ImGui_GetCursorPos(ctx)
		local width, height = reaper.ImGui_GetWindowSize(ctx) 
		local rv, macro_name = reaper.TrackFX_GetParamName(track, fx, macro_param_id)		
		local macro_name_clipped = ClipText(macro_name, width - x - win_padding_x - 6)		
		reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		-- if reaper.ImGui_Button(ctx, macro_name_clipped, width - x - win_padding_x, 18) then		
		-- 	if t_last_param.param then 
		-- 		if touched_fx + (t_last_param.param * 0.1) == fx + (macro_param_id * 0.1) then -- Check if last touched param is the macro itself
		-- 			reaper.ShowMessageBox("A Macro parameter cannot be mapped to itself", "MAPPING FAILED", 0)
		-- 		else
		-- 			-- Keep parameter current value if no native modulation is active
		-- 			local new_baseline
		-- 			if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
		-- 				new_baseline = t_pm_data.baseline
		-- 			else				
		-- 				new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
		-- 			end
		-- 			LinkParam(track, touched_fx, fx, touched_param, macro_param_id, new_baseline, param_is_linked_to_anything, false)
		-- 		end
		-- 	else
		-- 		reaper.ShowMessageBox("You must adjust an FX parameter before mapping to this macro", "MAPPING FAILED", 0)
		-- 	end
		-- end

		local link_confirmed
		if reaper.ImGui_Button(ctx, macro_name_clipped, width - x - win_padding_x, 18) then	
			if t_last_param.param then	
				if touched_fx + (t_last_param.param * 0.1) == fx + (macro_param_id * 0.1) then -- Check if last touched param is the macro itself
					if user_os == "Win" then
						StartModalWorkaround("macro_error_map_to_itself" .. str_index)
					else					
						reaper.ShowMessageBox("A Macro parameter cannot be mapped to itself", "MAPPING FAILED", 0)
					end
				else				

					-- -- Keep parameter current value if no native modulation is active
					-- local new_baseline
					-- if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
					-- 	new_baseline = t_pm_data.baseline
					-- else				
					-- 	new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
					-- end

					if param_is_linked_to_anything == 1 then
						if user_os == "Win" then
							StartModalWorkaround("macro_overwrite" .. str_index)
						else	
							local _, link_source_param_name = reaper.TrackFX_GetParamName(track, t_pm_data.link_source_fx, t_pm_data.link_source_param)
							local user_input_overwrite = reaper.ShowMessageBox("The parameter is already mapped to\n[" .. link_source_param_name ..  "].\nAre you sure you want to overwrite the mapping?", "OVERWRITE MAPPING?", 4)
							if user_input_overwrite == 6 then -- YES
								link_confirmed = true
							end
						end
					else
						link_confirmed = true
					end

					-- LinkParam(track, touched_fx, fx, touched_param, mod_param_id, new_baseline, param_is_linked_to_anything, true)
				end
			else
				if user_os == "Win" then
					StartModalWorkaround("map_no_param")
				else	
					reaper.ShowMessageBox("\nYou must adjust an FX parameter before mapping to this modulator", "MAPPING FAILED", 0)
				end				
				-- reaper.ShowMessageBox("\nYou must adjust an FX parameter before mapping to this modulator", "MAPPING FAILED", 0)
			end
		end	

		if user_os == "Win" and modal_popup_id == "macro_error_map_to_itself" .. str_index and modal_popup == true then
			reaper.ShowMessageBox("A Macro parameter cannot be mapped to itself", "MAPPING FAILED", 0)
			ResetModalWorkaroundVariables()
		end			

		if user_os == "Win" and modal_popup_id == "macro_overwrite" .. str_index and modal_popup == true then
			local _, link_source_param_name = reaper.TrackFX_GetParamName(track, t_pm_data.link_source_fx, t_pm_data.link_source_param)
			local user_input_overwrite = reaper.ShowMessageBox("The parameter is already mapped to\n[" .. link_source_param_name ..  "].\nAre you sure you want to overwrite the mapping?", "OVERWRITE MAPPING?", 4)
			if user_input_overwrite == 6 then -- YES
				link_confirmed = true
			end			
			ResetModalWorkaroundVariables()
		end	

		if link_confirmed == true then
			-- Keep parameter current value if no native modulation is active
			local new_baseline
			if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 then
				new_baseline = t_pm_data.baseline
			else				
				new_baseline = reaper.TrackFX_GetParam(track, t_last_param.fx, t_last_param.param)
			end

			LinkParam(track, touched_fx, fx, touched_param, macro_param_id, new_baseline, param_is_linked_to_anything, true)
		end
		reaper.ImGui_PopFont(ctx)

		if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
			if user_os == "Win" then
				StartModalWorkaround("macro_alias")
			else					
				reaper.TrackFX_SetParam(track, fx, macro_param_id, macro_val) -- To set as last touched param
				Command(41145) -- FX: Set alias for last touched FX parameter
				force_update = true
			end
		end		

		if user_os == "Win" and modal_popup_id == "macro_alias" and modal_popup == true then
			reaper.TrackFX_SetParam(track, fx, macro_param_id, macro_val) -- To set as last touched param
			Command(41145) -- FX: Set alias for last touched FX parameter
		end				

		if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Right()) then
			if not _G["macroList" .. index] then _G["macroList" .. index] = 0 end
			if not _G["macroPopup" .. index] then _G["macroPopup" .. index] = 0 end
			-- Close all the other macro assign list before opening this one
			for i=1, 6 do
				if i ~= index then
					_G["macroList" .. i] = 0
					_G["macroPopup" .. i] = 0
				end
			end			
			_G["macroList" .. index] = 1 - _G["macroList" .. index]
			_G["macroPopup" .. index] = 1 - _G["macroPopup" .. index]
		end
		
		-- reaper.ImGui_OpenPopupOnItemClick(ctx, 'macro_popup' .. str_index, reaper.ImGui_PopupFlags_MouseButtonRight())		

		-- Macro assignations popup
		-- if reaper.ImGui_BeginPopupContextItem(ctx, 'macro_popup' .. str_index) then
		-- 	local popup_width, popup_height = reaper.ImGui_GetWindowSize(ctx)
		-- 	local x, y = reaper.ImGui_GetCursorPos( ctx )
		-- 	reaper.ImGui_SetCursorPos(ctx, (popup_width * 0.5) - (width * 0.5), y)
		-- 	reaper.ImGui_PushFont(ctx, fonts.medium_bold)
		-- 	if reaper.ImGui_Button(ctx, macro_name, width) then
		-- 		if user_os == "Win" then
		-- 			StartModalWorkaround("macro_alias")
		-- 		else					
		-- 			reaper.TrackFX_SetParam(track, fx, macro_param_id, macro_val) -- To set as last touched param
		-- 			Command(41145) -- FX: Set alias for last touched FX parameter
		-- 		end
		-- 	end		

		-- 	if user_os == "Win" and modal_popup_id == "macro_alias" and modal_popup == true then
		-- 		reaper.TrackFX_SetParam(track, fx, macro_param_id, macro_val) -- To set as last touched param
		-- 		Command(41145) -- FX: Set alias for last touched FX parameter
		-- 	end	

		-- 	reaper.ImGui_PopFont(ctx)
		-- 	ToolTip("Click to rename Macro")

		-- 	-- if proj_updated then
		-- 		t_assignations = GetAssignations(track, fx, macro_param_id) -- Need to optimize this potentially intense function
		-- 	-- end
		-- 	for i=1, #t_assignations do

		-- 		assignation_color = DarkerColor(t_color_palette[mod_container_table_id], 4)

		-- 		local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].param_name)
		-- 		local x, y = reaper.ImGui_GetCursorPos( ctx )
		-- 		reaper.ImGui_InvisibleButton(ctx, "hover_area", text_size_x, text_size_y)
		-- 		ToolTip("Alt-click: Delete assignation")

		-- 		if reaper.ImGui_IsItemHovered(ctx) then
		-- 			assignation_color = BrighterColor(t_color_palette[mod_container_table_id])
		-- 		end

		-- 		-- Set as last touched parameter
		-- 		if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
		-- 			local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
		-- 			reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
		-- 		end	

		-- 		-- Delete modulation
		-- 		if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then																				
		-- 			local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
		-- 			reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param

		-- 			local unlink_confirmed
		-- 			if user_os == "Win" then
		-- 				StartModalWorkaround("remove_mapping_macro_assign_list" .. i)
		-- 			else	
		-- 				local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
		-- 				if user_input_remove_mapping == 6 then -- YES
		-- 					unlink_confirmed = true
		-- 				end	
		-- 			end	
		-- 			-- UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
		-- 		end		

		-- 		if user_os == "Win" and modal_popup_id == "remove_mapping_macro_assign_list" .. i and modal_popup == true then
		-- 			local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
		-- 			if user_input_remove_mapping == 6 then -- YES
		-- 				unlink_confirmed = true
		-- 			end			
		-- 			ResetModalWorkaroundVariables()
		-- 		end										

		-- 		if unlink_confirmed == true then									
		-- 			UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
		-- 		end

		-- 		-- Draw the text with the determined color
		-- 		reaper.ImGui_SameLine(ctx)
		-- 		reaper.ImGui_SetCursorPos(ctx, x, y)
		-- 		reaper.ImGui_SetNextItemAllowOverlap(ctx)				
		-- 		reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].param_name)

		-- 		reaper.ImGui_SameLine(ctx)
		-- 		local assignation_color = white
		-- 		local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].fx_name)
		-- 		local x, y = reaper.ImGui_GetCursorPos( ctx )
		-- 		reaper.ImGui_InvisibleButton(ctx, "hover_area_fx", text_size_x, text_size_y)

		-- 		if reaper.ImGui_IsItemHovered(ctx) then
		-- 			assignation_color = full_white
		-- 		end

		-- 		-- Open FX
		-- 		if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
		-- 			reaper.TrackFX_Show(track, t_assignations[i].fx_id, 3) -- In floating window					
		-- 		elseif reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
		-- 			reaper.TrackFX_Show(track, t_assignations[i].fx_id, 1) -- In FXchain									
		-- 		end					

		-- 		-- Draw the fx name
		-- 		reaper.ImGui_SameLine(ctx)
		-- 		reaper.ImGui_SetCursorPos(ctx, x, y)
		-- 		reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].fx_name)	
		-- 	end

		-- 	if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
		-- 		reaper.ImGui_CloseCurrentPopup(ctx)
		-- 	end			

		-- 	reaper.ImGui_EndPopup(ctx)
		-- end		

		-- if reaper.ImGui_IsPopupOpen(ctx, 'macro_popup' .. str_index, 0) then			
		-- 	_G["macroPopup" .. str_index] = 1
		-- else
		-- 	_G["macroPopup" .. str_index] = 0
		-- end								

		if t_last_param.param and (touched_fx + (t_last_param.param * 0.1)) ~= (fx + (macro_param_id * 0.1)) then -- Check if last touched param is not the macro itself
			if param_is_linked_to_anything == 1 then
				ToolTip("Left-click: Remap [" .. t_last_param.param_name .. "] to MACRO " .. index .. "\n\nRight-click: Show Assignations\nShift+Click: Rename macro")	
			else
				ToolTip("Left-click: Map [" .. t_last_param.param_name .. "] to MACRO " .. index .. "\n\nRight-click: Show Assignations\nShift+Click: Rename macro")
			end	
		else
			ToolTip("Right-click: Show Assignations\nShift+Click: Rename macro")
		end			

		reaper.ImGui_Dummy(ctx, 0, 0)

		local view_mod_range_slider = math.max(macro_is_linked, lfo_active, acs_active) -- Check if any modulation is active on the macro itself
		if view_mod_range_slider == 1 then
			_G["macro_baseline" .. str_index] = baseline
			_G["macro" .. str_index] = macro_val
			-- _G["rv_macro" .. str_index], _G["macro_baseline" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro_baseline" .. str_index], _G["macro" .. str_index], min, max, width - x - win_padding_x, 13, 50, true, 1, view_mod_range_slider, BrighterColor(UI_color, 1))
			_G["rv_macro" .. str_index], _G["macro_baseline" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro_baseline" .. str_index], _G["macro" .. str_index], min, max, width - x - win_padding_x, 13, 50, true, 1, view_mod_range_slider, BrighterColor2(t_color_palette[mod_container_table_id], 0.3))
			if _G["rv_macro" .. str_index] == true then	

				-- Check if conditions are fullfilled to show Macro value
				local show_macro_val
				if (param_lock == 1 and (touched_fx + (touched_param * 0.1)) == (fx + (macro_param_id * 0.1))) then -- If Flashmob is lock but the last-touched FX param is this macro
					show_macro_val = true
				-- elseif param_lock == 0 and t_last_param.param and macro_mod_enable == 1 then
				elseif param_lock == 0 and macro_mod_enable == 1 then
					show_macro_val = true
				end

				if show_macro_val then
					reaper.TrackFX_SetParam(track, fx, macro_param_id, _G["macro" .. str_index]) -- Set as last touched param
					GetLastTouchedFXParam(track)
					GetPMData(track, t_last_param.fx, t_last_param.param) -- Update data because macro values are displayed in the FX PARAMETER header
				end						
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. macro_param_id .. ".mod.baseline", _G["macro_baseline" .. str_index])								
			end				

		else
			_G["macro" .. str_index] = macro_val
			-- _G["rv_macro" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro" .. str_index], 0, min, max, width - x - win_padding_x, 13, 50, false, 1, 0, BrighterColor(UI_color, 1))
			_G["rv_macro" .. str_index], _G["macro" .. str_index] = CustomSlider("##" .. macro_name, _G["macro" .. str_index], 0, min, max, width - x - win_padding_x, 13, 50, false, 1, 0, BrighterColor2(t_color_palette[mod_container_table_id], 0.3))
			if _G["rv_macro" .. str_index] == true then
				reaper.TrackFX_SetParam(track, fx, macro_param_id, _G["macro" .. str_index])
			end			
		end

		if _G["macroList" .. index] == 1 then	
			local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
			local popup_width, popup_height = reaper.ImGui_GetWindowSize(ctx)
			local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)

			reaper.ImGui_DrawList_AddLine(draw_list, screen_x - win_padding_x, screen_y + 4, screen_x + width - win_padding_x, screen_y + 4, mod_border_color, vertical_line_border_size)			

			-- if proj_updated then
				t_assignations = GetAssignations(track, fx, macro_param_id) -- Need to optimize this potentially intense function
			-- end

			overview_baseline = nil
			overview_scale = nil			

			if #t_assignations == 0 then
				reaper.ImGui_Dummy(ctx, 0, 7)
				reaper.ImGui_Text(ctx, "No Assignation")
			else
				for i=1, #t_assignations do

					if i == 1 then reaper.ImGui_Dummy(ctx, 0, 6) end
					-- assignation_color = DarkerColor(t_color_palette[mod_container_table_id], 4)
					assignation_color = DarkerColor2(t_color_palette[mod_container_table_id], 0.1)

					local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].param_name)
					local x, y = reaper.ImGui_GetCursorPos( ctx )
					reaper.ImGui_InvisibleButton(ctx, "hover_area", text_size_x, text_size_y)
					ToolTip("Alt-click: Delete assignation")

					if reaper.ImGui_IsItemHovered(ctx) then
						-- assignation_color = BrighterColor(t_color_palette[mod_container_table_id])
						assignation_color = BrighterColor2(t_color_palette[mod_container_table_id], 0.3)
					end

					-- Set as last touched parameter
					if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
						local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param
					end	

					-- Delete modulation
					local unlink_confirmed					
					if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then																				
						local current_val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, current_val) -- To set as last touched param

						if user_os == "Win" then
							StartModalWorkaround("remove_mapping_macro_assign_list" .. i)
						else	
							local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
							if user_input_remove_mapping == 6 then -- YES
								unlink_confirmed = true
							end	
						end	
						-- UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
					end		

					if user_os == "Win" and modal_popup_id == "remove_mapping_macro_assign_list" .. i and modal_popup == true then
						local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
						if user_input_remove_mapping == 6 then -- YES
							unlink_confirmed = true
						end			
						ResetModalWorkaroundVariables()
					end										

					if unlink_confirmed == true then									
						UnlinkParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)	
					end

					-- Draw the text with the determined color
					reaper.ImGui_SameLine(ctx)
					reaper.ImGui_SetCursorPos(ctx, x, y)
					reaper.ImGui_SetNextItemAllowOverlap(ctx)				
					reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].param_name)

					-- Draw FX name if this is a new FX
					if i == 1 or t_assignations[i].fx_id ~= t_assignations[i-1].fx_id then
						reaper.ImGui_SameLine(ctx)
						local assignation_color = white
						local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].fx_name)
						local x, y = reaper.ImGui_GetCursorPos( ctx )
						reaper.ImGui_InvisibleButton(ctx, "hover_area_fx", text_size_x, text_size_y)

						if reaper.ImGui_IsItemHovered(ctx) then
							assignation_color = full_white
						end

						-- Open FX
						if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
							if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
								reaper.TrackFX_Show(track, t_assignations[i].fx_id, 3) -- In floating window					
							else
								reaper.TrackFX_Show(track, t_assignations[i].fx_id, 1) -- In FXchain	
							end
						end					

						-- Draw the fx name
						reaper.ImGui_SameLine(ctx)
						reaper.ImGui_PushFont(ctx, fonts.small)
						reaper.ImGui_SetCursorPos(ctx, x, y + 3)
						local width_for_fxName = reaper.ImGui_GetContentRegionAvail(ctx)
						local fx_name_clipped = ClipText(t_assignations[i].fx_name, width_for_fxName)
						reaper.ImGui_TextColored(ctx, assignation_color, fx_name_clipped)
						if fx_name_clipped ~= t_assignations[i].fx_name then ToolTip(t_assignations[i].fx_name) end
						reaper.ImGui_PopFont(ctx)
					end

					-- Show baseline and mod amount sliders
					reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), t_color_palette[mod_container_table_id])
					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), t_color_palette[mod_container_table_id])

					local val, min, max = reaper.TrackFX_GetParamEx(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					local _, offset = reaper.TrackFX_GetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".mod.baseline")
					local offset_formatted

					if max ~= 1 then -- If effect is a JSFX
						-- last_touched_param_value = (last_touched_param_value / max) - min -- Useful for JSFX with parameter value range > 1
						offset_formatted = offset
						offset_formatted = string.format("%.2f", offset_formatted)
					else
						rv, offset_formatted = reaper.TrackFX_FormatParamValueNormalized(track, t_assignations[i].fx_id, t_assignations[i].param_id, offset, "")												
						offset_formatted = ReplaceRareUnicode(offset_formatted)	
					end

					offset_formatted = offset_formatted:gsub("%%", "%%%%") -- Escape "%"					

					-- Special case of plugins not supporting the Cockos VST extension (hard-coded)
					if t_assignations[i].fx_name_raw:find("Valhalla DSP") then
						local baseline_rounded = string.format("%.2f", offset)
						offset_formatted = baseline_rounded
					end


					reaper.ImGui_SetNextItemWidth(ctx, popup_width * 0.5 - (win_padding_x * 2))
					local rv_offset, offset = reaper.ImGui_SliderDouble(ctx, "##offset" .. i, offset, min, max, offset_formatted)
					-- local rv_offset, offset = reaper.ImGui_SliderDouble(ctx, "##offset" .. i, offset, min, max)
					if rv_offset then

						-- active as last-touched FX param
						local val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, val)

						reaper.TrackFX_SetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".mod.baseline", offset)
					end

					-- show mod range
					if reaper.ImGui_IsItemActive(ctx) then
						overview_baseline = 1
					end	

					reaper.ImGui_SameLine(ctx)

					local _, amount = reaper.TrackFX_GetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".plink.scale")
					local amount_formatted = string.format('%.1f %%%%', amount * 100)

					reaper.ImGui_SetNextItemWidth(ctx, popup_width * 0.5 - (win_padding_x * 2))
					local rv_amount, amount = reaper.ImGui_SliderDouble(ctx, "##amount" .. i, amount, -1, 1, amount_formatted)
					if rv_amount then

						show_mod_value = true

						-- active as last-touched FX param
						local val = reaper.TrackFX_GetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id)
						reaper.TrackFX_SetParam(track, t_assignations[i].fx_id, t_assignations[i].param_id, val)

						reaper.TrackFX_SetNamedConfigParm(track, t_assignations[i].fx_id, "param." .. t_assignations[i].param_id .. ".plink.scale", amount)
					end	

					-- show mod range
					if reaper.ImGui_IsItemActive(ctx) then
						overview_scale = 1
					end						

					-- Update data
					if rv_offset or rv_amount then
						GetLastTouchedFXParam(track)
						GetPMData(track, t_assignations[i].fx_id, t_assignations[i].param_id)
					end					

					reaper.ImGui_PopStyleVar(ctx, 1)
					reaper.ImGui_PopStyleColor(ctx, 2)


					-- reaper.ImGui_SameLine(ctx)
					-- local assignation_color = white
					-- local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, t_assignations[i].fx_name)
					-- local x, y = reaper.ImGui_GetCursorPos( ctx )
					-- reaper.ImGui_InvisibleButton(ctx, "hover_area_fx", text_size_x, text_size_y)

					-- if reaper.ImGui_IsItemHovered(ctx) then
					-- 	assignation_color = full_white
					-- end

					-- -- Open FX
					-- if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
					-- 	reaper.TrackFX_Show(track, t_assignations[i].fx_id, 3) -- In floating window					
					-- elseif reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					-- 	reaper.TrackFX_Show(track, t_assignations[i].fx_id, 1) -- In FXchain									
					-- end					

					-- -- Draw the fx name
					-- reaper.ImGui_SameLine(ctx)
					-- reaper.ImGui_SetCursorPos(ctx, x, y)
					-- reaper.ImGui_TextColored(ctx, assignation_color, t_assignations[i].fx_name)	
				end
			end
		end	

		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx, 4)
	reaper.ImGui_PopStyleVar(ctx, 2)
end

function DrawMIDILearn(track, fx, param)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	if t_pm_data.midi_learn and t_pm_data.midi_learn ~= 0 then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 2)
	else
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor2(white, 0.5))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)
	end	
	local visible = reaper.ImGui_BeginChild(ctx, 'MIDI_Child', 0, 20 + win_padding_y * 2, reaper.ImGui_ChildFlags_Border(), window_flags)
	if visible then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), DarkerColor(track_color, 2))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), BrighterColor(track_color, 2))
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), BrighterColor(track_color, 2))
		local width, height = reaper.ImGui_GetWindowSize(ctx)	
		local x, y = reaper.ImGui_GetCursorPos(ctx)

		local midi_learn_active
		if t_pm_data.midi_learn and t_pm_data.midi_learn ~= 0 then
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
		-- ToolTip("currently not working due to a Reaper bug")	

		if rv_midi_active then
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".mod.active", 1) -- Active PM in case it was removed in Overview
			midi_learn_active = midi_learn_active and 1 or 0
			-- reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.active", t_pm_data.midi_learn)
			local current_val = reaper.TrackFX_GetParam(track, fx, param)
			reaper.TrackFX_SetParam(track, fx, param, current_val) -- Safety to set as last touched FX parameter
			-- reaper.SetCursorContext(1) -- Set focus back to arrange
			-- reaper.ImGui_SetKeyboardFocusHere(ctx)
			if user_os == "Win" then
				StartModalWorkaround("nativeTab_midiLearn")
			else
				Command(41144) -- FX: Set MIDI learn for last touched FX parameter
				GetPMData(track, fx, param)
			end
		end

		if user_os == "Win" and modal_popup_id == "nativeTab_midiLearn" and modal_popup == true then
			Command(41144) -- FX: Set MIDI learn for last touched FX parameter			
			GetPMData(track, fx, param)		
			ResetModalWorkaroundVariables()
		end

		reaper.ImGui_PopStyleColor(ctx, 3)
		reaper.ImGui_EndChild(ctx)
	end
	reaper.ImGui_PopStyleColor(ctx)
	reaper.ImGui_PopStyleVar(ctx, 2)
end

function DrawNativeLFO(track, fx, param)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	if t_pm_data.lfo_active == 1 then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 2)
		vertical_line_thickness = 2
	else
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor2(white, 0.5))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)
		vertical_line_thickness = 1
	end
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
		ToolTip("Enable/disable Native LFO")
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
			reaper.ImGui_DrawList_AddLine(draw_list, x - win_padding_x, y, x + width - win_padding_x, y, DarkerColor(track_color), vertical_line_thickness)

			reaper.ImGui_Dummy(ctx, 0, 10)

			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the sliders
			-- LFO strength
			local text_lfo_strength = "Strength"
			local text_lfo_strength_clipped = ClipText(text_lfo_strength, GetLabelMaxWidth())
			rv_lfo_strength, t_lfo_params.lfo_strength = reaper.ImGui_SliderDouble(ctx, text_lfo_strength_clipped, t_lfo_params.lfo_strength, 0, 1, string.format("%.2f", t_lfo_params.lfo_strength * 100), reaper.ImGui_SliderFlags_NoInput())
			if rv_lfo_strength then				
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.strength", t_lfo_params.lfo_strength)
			end				
			if text_lfo_strength_clipped ~= text_lfo_strength then ToolTip(text_lfo_strength, 1) end	
			if reaper.ImGui_IsItemActive(ctx) then
				lfo_strength_adjust = 1
			else
				lfo_strength_adjust = nil
			end
			
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
			if text_lfo_shape_clipped ~= text_lfo_shape then ToolTip(text_lfo_shape, 1) end

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
				-- local beat = {"1/16", "1/8", "1/4", "1/2", "1/1", "2/1"}			
				-- local current_item = 0
				-- if t_lfo_params.lfo_speed == 0.25 then combo_preview_value = beat[1]
				-- elseif t_lfo_params.lfo_speed > 0.25 and t_lfo_params.lfo_speed <= 0.5 then combo_preview_value = beat[2]
				-- elseif t_lfo_params.lfo_speed > 0.5 and t_lfo_params.lfo_speed <= 1 then combo_preview_value = beat[3]
				-- elseif t_lfo_params.lfo_speed > 1 and t_lfo_params.lfo_speed <= 2 then combo_preview_value = beat[4]
				-- elseif t_lfo_params.lfo_speed > 2 and t_lfo_params.lfo_speed <= 4 then combo_preview_value = beat[5]
				-- elseif t_lfo_params.lfo_speed > 4 and t_lfo_params.lfo_speed <= 8 then combo_preview_value = beat[6]					
				-- end

				-- if reaper.ImGui_BeginCombo(ctx, text_lfo_speed_clipped, combo_preview_value) then
				-- 	for i,v in ipairs(beat) do
				-- 		local is_selected = current_item == i
				-- 		if reaper.ImGui_Selectable(ctx, beat[i], is_selected) then
				-- 			current_item = i
				-- 			if current_item == 1 then
				-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 0.25)
				-- 			elseif current_item == 2 then
				-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 0.5)
				-- 			elseif current_item == 3 then
				-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 1)
				-- 			elseif current_item == 4 then
				-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 2)
				-- 			elseif current_item == 5 then
				-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 4)
				-- 			elseif current_item == 6 then
				-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 8)																												
				-- 			end
				-- 		end

				-- 		-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
				-- 		if is_selected then
				-- 			reaper.ImGui_SetItemDefaultFocus(ctx)
				-- 		end
				-- 	end
				-- 	reaper.ImGui_EndCombo(ctx)
				-- end	
		
				local beat = '1/16\0' .. '1/8\0' .. '1/4\0' .. '1/2\0' .. '1/1\0' .. '2/1\0'
				local current_beat = 0
				if t_lfo_params.lfo_speed == 0.25 then current_beat = 0
				elseif t_lfo_params.lfo_speed > 0.25 and t_lfo_params.lfo_speed <= 0.5 then current_beat = 1
				elseif t_lfo_params.lfo_speed > 0.5 and t_lfo_params.lfo_speed <= 1 then current_beat = 2
				elseif t_lfo_params.lfo_speed > 1 and t_lfo_params.lfo_speed <= 2 then current_beat = 3
				elseif t_lfo_params.lfo_speed > 2 and t_lfo_params.lfo_speed <= 4 then current_beat = 4
				elseif t_lfo_params.lfo_speed > 4 and t_lfo_params.lfo_speed <= 8 then current_beat = 5
				end			
			
				rv_beat, current_beat = reaper.ImGui_Combo(ctx, text_lfo_speed_clipped, current_beat, beat)

				if rv_beat then
					if current_beat == 0 then
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 0.25)
					elseif current_beat == 1 then
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 0.5)
					elseif current_beat == 2 then
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 1)
					elseif current_beat == 3 then
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 2)
					elseif current_beat == 4 then
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 4)
					elseif current_beat == 5 then
						reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.speed", 8)																												
					end
				end				

			end
			if text_lfo_speed_clipped ~= text_lfo_speed then ToolTip(text_lfo_speed, 1) end	

			-- LFO phase
			local text_lfo_phase = "Phase"
			local text_lfo_phase_clipped = ClipText(text_lfo_phase, GetLabelMaxWidth())
			rv_lfo_phase, t_lfo_params.lfo_phase = reaper.ImGui_SliderDouble(ctx, text_lfo_phase_clipped, t_lfo_params.lfo_phase, 0, 1, formatIn, reaper.ImGui_SliderFlags_NoInput())
			if rv_lfo_phase then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".lfo.phase", t_lfo_params.lfo_phase)
			end				
			if text_lfo_phase_clipped ~= text_lfo_phase then ToolTip(text_lfo_phase, 1) end	

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
	reaper.ImGui_PopStyleVar(ctx, 2)
end

function DrawNativeACS(track, fx, param)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5.0)
	if t_pm_data.acs_active == 1 then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor(track_color))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 2)
		vertical_line_thickness = 2
	else
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor2(white, 0.5))
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)
		vertical_line_thickness = 1
	end
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
		ToolTip("Enable/disable Native Audio Follower")
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
			reaper.ImGui_DrawList_AddLine(draw_list, x - win_padding_x, y, x + width - win_padding_x, y, DarkerColor(track_color), vertical_line_thickness)

			reaper.ImGui_Dummy(ctx, 0, 10)

			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the sliders
			-- acs strength
			local text_acs_strength = "Strength"
			local text_acs_strength_clipped = ClipText(text_acs_strength, GetLabelMaxWidth())
			rv_acs_strength, t_acs_params.acs_strength = reaper.ImGui_SliderDouble(ctx, text_acs_strength_clipped, t_acs_params.acs_strength, 0, 1, string.format("%.2f", t_acs_params.acs_strength * 100), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_strength then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.strength", t_acs_params.acs_strength)
			end	
			if text_acs_strength_clipped ~= text_acs_strength then ToolTip(text_acs_strength, 1) end	

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
			if text_acs_attack_clipped ~= text_acs_attack then ToolTip(text_acs_attack, 1) end	

			-- acs release
			local text_acs_release = "Release"
			local text_acs_release_clipped = ClipText(text_acs_release, GetLabelMaxWidth())
			rv_acs_release, t_acs_params.acs_release = reaper.ImGui_SliderDouble(ctx, text_acs_release_clipped, t_acs_params.acs_release, 0, 1000,string.format("%.0f", t_acs_params.acs_release), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_release then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.release", t_acs_params.acs_release)
			end	
			if text_acs_release_clipped ~= text_acs_release then ToolTip(text_acs_release, 1) end	

			-- min volume
			local text_acs_dblo = "Min Vol"
			local text_acs_dblo_clipped = ClipText(text_acs_dblo, GetLabelMaxWidth())
			rv_acs_dblo, t_acs_params.acs_dblo = reaper.ImGui_SliderDouble(ctx, text_acs_dblo_clipped, t_acs_params.acs_dblo, -60, 12, string.format("%.2f", t_acs_params.acs_dblo), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_dblo then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dblo", t_acs_params.acs_dblo)
			end	
			if text_acs_dblo_clipped ~= text_acs_dblo then ToolTip(text_acs_dblo, 1) end	

			-- min volume
			local text_acs_dbhi = "Max Vol"
			local text_acs_dbhi_clipped = ClipText(text_acs_dbhi, GetLabelMaxWidth())
			rv_acs_dbhi, t_acs_params.acs_dbhi = reaper.ImGui_SliderDouble(ctx, text_acs_dbhi_clipped, t_acs_params.acs_dbhi, -60, 12, string.format("%.2f", t_acs_params.acs_dbhi), reaper.ImGui_SliderFlags_NoInput())
			if rv_acs_dbhi then
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.dbhi", t_acs_params.acs_dbhi)
			end	
			if text_acs_dbhi_clipped ~= text_acs_dbhi then ToolTip(text_acs_dbhi, 1) end	
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
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0) -- Un-round the sliders
			local text_acs_chan = "Channels"
			local text_acs_chan_clipped = ClipText(text_acs_chan, GetLabelMaxWidth())		

			-- Sloppy code
			-- local chan = {"1/2", "3/4", "5/6", "7/8"}			
			-- local current_item = 0
			-- if t_acs_params.acs_chan >= 0 and t_acs_params.acs_chan < 2 then combo_preview_value = chan[1]				
			-- elseif t_acs_params.acs_chan >= 2 and t_acs_params.acs_chan < 4 then combo_preview_value = chan[2]
			-- elseif t_acs_params.acs_chan >= 4 and t_acs_params.acs_chan < 6 then combo_preview_value = chan[3]
			-- elseif t_acs_params.acs_chan >= 6 and t_acs_params.acs_chan < 8 then combo_preview_value = chan[4]
			-- end

			-- local track_ch = (reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") * 0.5)
			-- -- local actual_chan -- after track channel evaluation
			-- for i=1, #chan do
			-- 	if i > track_ch then
			-- 		chan[i] = nil
			-- 	end
			-- end

			-- if reaper.ImGui_BeginCombo(ctx, text_acs_chan_clipped, combo_preview_value) then
			-- 	for i,v in ipairs(chan) do
			-- 		local is_selected = current_item == i
			-- 		if reaper.ImGui_Selectable(ctx, chan[i], is_selected) then
			-- 			current_item = i
			-- 			if current_item == 1 then
			-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 0)						
			-- 			elseif current_item == 2 then
			-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 2)
			-- 			elseif current_item == 3 then
			-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 4)
			-- 			elseif current_item == 4 then
			-- 				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 6)																												
			-- 			end
			-- 			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.stereo", 1)
			-- 		end

			-- 		-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
			-- 		if is_selected then
			-- 			reaper.ImGui_SetItemDefaultFocus(ctx)
			-- 		end
			-- 	end
			-- 	reaper.ImGui_EndCombo(ctx)
			-- end	

			local t_chan = {"1/2", "3/4", "5/6", "7/8"}	
			
			local track_ch = (reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") * 0.5)
			-- local actual_chan -- after track channel evaluation
			for i=1, #t_chan do
				if i > track_ch then
					t_chan[i] = nil
				end
			end	
			
			-- chan = table.concat(chan, "\0")	
			chan = ""
			for i=1, #t_chan do
				chan = chan .. t_chan[i] .. '\0'
			end		

			-- local chan = '1/2\0' .. '3/4\0' .. '5/6\0' .. '7/8\0'

			local current_item = 0
			if t_acs_params.acs_chan >= 0 and t_acs_params.acs_chan < 2 then current_item = 0
			elseif t_acs_params.acs_chan >= 2 and t_acs_params.acs_chan < 4 then current_item = 1
			elseif t_acs_params.acs_chan >= 4 and t_acs_params.acs_chan < 6 then current_item = 2
			elseif t_acs_params.acs_chan >= 6 and t_acs_params.acs_chan < 8 then current_item = 3
			end

			rv_chan, current_item = reaper.ImGui_Combo(ctx, text_acs_chan_clipped, current_item, chan)

			if rv_chan then
				-- reaper.ImGui_SetItemDefaultFocus(ctx)
				if current_item == 0 then
					reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 0)						
				elseif current_item == 1 then
					reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 2)
				elseif current_item == 2 then
					reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 4)
				elseif current_item == 3 then
					reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.chan", 6)																												
				end
				reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".acs.stereo", 1)
			end								

			if text_acs_chan_clipped ~= text_acs_chan then ToolTip(text_acs_chan, 1) end				
			reaper.ImGui_PopStyleVar(ctx, 1)
		end
		reaper.ImGui_PopStyleColor(ctx, 2)
		reaper.ImGui_EndChild(ctx)
	end
	hover_acs = reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_RectOnly())
	reaper.ImGui_PopStyleColor(ctx)
	reaper.ImGui_PopStyleVar(ctx, 2)
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
		ToolTip("Enable/disable Native LFO")
	elseif icon == 2 then
		ADEnvelope(draw_list, x, y, width, height, icon_color, 2)
		ToolTip("Enable/disable Native Audio Follower")
	elseif icon == 3 then
		Midi(draw_list, x, y, 13, height, icon_color, 2)
		ToolTip("MIDI learn")
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
			reaper.TrackFX_SetNamedConfigParm(track, fx, "param." .. param .. ".mod.active", 1)
			-- Command(41144) -- FX: Set MIDI learn for last touched FX parameter
			if user_os == "Win" then
				StartModalWorkaround("icon_midiLearn")
			else
				Command(41144) -- FX: Set MIDI learn for last touched FX parameter
				GetPMData(track, fx, param)
			end
		end
	end

	if user_os == "Win" and modal_popup_id == "icon_midiLearn" and modal_popup == true then
		Command(41144) -- FX: Set MIDI learn for last touched FX parameter			
		GetPMData(track, fx, param)		
		ResetModalWorkaroundVariables()
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
	local padding_text = 14

	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 0, 0)


	-- Initialize header state if needed
	if custom_headers[id] == nil then custom_headers[id] = false end
	local is_open = custom_headers[id]

	-- Click detection
	reaper.ImGui_SetCursorPos(ctx, 0, y) -- Reset cursor for button area
	reaper.ImGui_InvisibleButton(ctx, id, width, height)

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
	reaper.ImGui_SetCursorPosY(ctx, y + height)

	reaper.ImGui_PopStyleVar(ctx, 3)

	return custom_headers[id]
end

function CustomButton(ctx, index, button_nb, width, height, track, fx, param)
	local hovered, clicked
	local before_x, before_y = reaper.ImGui_GetCursorPos(ctx)
	local param_lock_toggle, macroMod_toggle, helpPage_toggle, settingsPage_toggle, helpPage_close, settingsPage_close

	if (index == 1 and param_lock == 1) or (index == 2 and macro_mod_enable == 1) or (index == 4 and help_page == 1) or (index == 5 and settings_page == 1) then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), track_color)
	end

	if index == 2 and param_lock == 1 then
		reaper.ImGui_BeginDisabled(ctx)
	end

	-- if (index == 1 or index == 2) and rv_flashmob == false then
	-- 	reaper.ImGui_BeginDisabled(ctx)
	-- end	

	reaper.ImGui_Button(ctx, "##"..index, width, height)

	-- if (index == 1 or index == 2) and rv_flashmob == false then
	-- 	reaper.ImGui_EndDisabled(ctx)
	-- end

	if index == 2 and param_lock == 1 then
		reaper.ImGui_EndDisabled(ctx)
	end

	if index == 1 then ToolTip("Lock current Flashmob and last-touched FX param") end
	if index == 2 then ToolTip("Enable modulation mapping for macros (touch macro sliders)") end
	if index == 3 then ToolTip("Add another Flashmob instance") end
	if index == 4 then ToolTip("Help") end
	if index == 5 then ToolTip("Overview") end

	if reaper.ImGui_IsItemHovered(ctx) then
		hovered = true
		if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
			clicked = true
			if index == 1 then param_lock_toggle = true end			
			if index == 2 then macroMod_toggle = true end
			if index == 3 then
				-- reaper.TrackFX_AddByName(track, "../Scripts/VF_ReaScripts Beta/Flashmob/Flashmob.RfxChain", false, 1000)	-- last argument adds an instance if one is not found at the first FX chain index								
				if reaper.file_exists(script_path .. "FXChains/" .. default_preset .. ".RfxChain") then				
					AddFlashmobInstance(track)
					mod_container_id = reaper.TrackFX_GetCount(track) - 1
					if not mod_container_table_id then mod_container_table_id = 0 end
					mod_container_table_id = mod_container_table_id + 1
					reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id, 1)
					reload_settings = true
				else
					if user_os == "Win" then
						StartModalWorkaround("error_missing_fxchain" .. str_index)
					else	
						reaper.ShowMessageBox(script_path .. "FXChains/" .. default_preset .. ".RfxChain file is missing.\n\nPlease, choose another default preset in the script settings or reinstall the script.", "ERROR", 0)
					end								
				end					
			end	
			if index == 4 then 
				helpPage_toggle = true 
				settingsPage_close = true
			end	
			if index == 5 then 
				settingsPage_toggle = true
				helpPage_close = true
			end	
		end
	end

	if index < button_nb then
		reaper.ImGui_SameLine(ctx)
	end				
	local after_x, after_y = reaper.ImGui_GetCursorPos(ctx)		

	if (index == 1 and param_lock == 1) or (index == 2 and macro_mod_enable == 1) or (index == 4 and help_page == 1) or (index == 5 and settings_page == 1) then
		reaper.ImGui_PopStyleColor(ctx, 1)
	end

	-- Change option after the button color push/pop
	if param_lock_toggle then 
		param_lock = 1 - param_lock

		-- Set the locked parameter as the last-touched one when desactivate the lock
		if param_lock == 0 and t_last_param.param then
			local current_val = reaper.TrackFX_GetParam(track, fx, param)
			reaper.TrackFX_SetParam(track, fx, param, current_val)
		end		
	end	

	if macroMod_toggle then 
		macro_mod_enable = 1 - macro_mod_enable

		-- Restore the previous non-macro last-touched FX param when desactivate the "modulation mapping for macro"
		if macro_mod_enable == 0 and t_previous_param.param then 
			local previous_current_val = reaper.TrackFX_GetParam(track, t_previous_param.fx, t_previous_param.param)
			local retval, param_name = reaper.TrackFX_GetParamName(track, t_previous_param.fx, t_previous_param.param)
			if previous_current_val ~= -1 and param_name == t_previous_param.param_name then -- If parameter or fx exist and have the same name (very very small chance of problem but not 100% rock proof)
				reaper.TrackFX_SetParam(track, t_previous_param.fx, t_previous_param.param, previous_current_val)	
			else -- reset last-touched parameter data
				t_last_param = {}
				t_previous_param = {}
				t_pm_data = {}
				t_pm_lfo = {}
				t_pm_acs = {}				
				last_param_guid_hack = nil					
				param_is_valid = false
				result = -1
			end
		end
	end

	if helpPage_toggle then help_page = 1 - help_page end
	if helpPage_close then help_page = 0 end
	if settingsPage_toggle then settings_page = 1 - settings_page end
	if settingsPage_close then settings_page = 0 end

	-- Display icon
	reaper.ImGui_SetCursorPos(ctx, before_x + (width * 0.5) - 8, before_y + 2)   

	if index == 1 then			
		if hovered then
			reaper.ImGui_Image(ctx, img_lock_hover, reaper.ImGui_Image_GetSize(img_lock_hover))   
		elseif param_lock == 1 then
			reaper.ImGui_Image(ctx, img_lock_on, reaper.ImGui_Image_GetSize(img_lock_on))   
		else
			reaper.ImGui_Image(ctx, img_lock_off, reaper.ImGui_Image_GetSize(img_lock_off))   
		end
	end

	if index == 2 then			
		if param_lock == 1 then
			if macro_mod_enable == 1 then
				reaper.ImGui_Image(ctx, img_macroMod_on, reaper.ImGui_Image_GetSize(img_macroMod_on))   
			else
				reaper.ImGui_Image(ctx, img_macroMod_off_disabled, reaper.ImGui_Image_GetSize(img_macroMod_off_disabled))   
			end
		else
			if hovered then
				reaper.ImGui_Image(ctx, img_macroMod_hover, reaper.ImGui_Image_GetSize(img_macroMod_hover))   
			elseif macro_mod_enable == 1 then
				reaper.ImGui_Image(ctx, img_macroMod_on, reaper.ImGui_Image_GetSize(img_macroMod_on))   
			else
				reaper.ImGui_Image(ctx, img_macroMod_off, reaper.ImGui_Image_GetSize(img_macroMod_off))   
			end
		end
	end

	if index == 3 then	
		if hovered then
			reaper.ImGui_Image(ctx, img_addInst_hover, reaper.ImGui_Image_GetSize(img_addInst_hover))
		else
			reaper.ImGui_Image(ctx, img_addInst_off, reaper.ImGui_Image_GetSize(img_addInst_off))
		end
	end   

	if index == 4 then	
		if hovered then
			reaper.ImGui_Image(ctx, img_help_hover, reaper.ImGui_Image_GetSize(img_help_hover))
		elseif help_page == 1 then
			reaper.ImGui_Image(ctx, img_help_on, reaper.ImGui_Image_GetSize(img_help_on))
		else
			reaper.ImGui_Image(ctx, img_help_off, reaper.ImGui_Image_GetSize(img_help_off))
		end
	end  

	if index == 5 then	  
		if hovered then
			reaper.ImGui_Image(ctx, img_settings_hover, reaper.ImGui_Image_GetSize(img_settings_hover))
		elseif settings_page == 1 then
			reaper.ImGui_Image(ctx, img_settings_on, reaper.ImGui_Image_GetSize(img_settings_on))
		else
			reaper.ImGui_Image(ctx, img_settings_off, reaper.ImGui_Image_GetSize(img_settings_off))
		end
	end   

	reaper.ImGui_SetCursorPos(ctx, after_x, after_y)
end

function OverviewButton(ctx, width, height, track)
	local hovered, clicked
	local before_x, before_y = reaper.ImGui_GetCursorPos(ctx)
	local overview_toggle

	if full == 1 then
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), track_color)
	end

	reaper.ImGui_Button(ctx, "##Full", width, height)

	-- if (index == 1 or index == 2) and rv_flashmob == false then
	-- 	reaper.ImGui_EndDisabled(ctx)
	-- end

	ToolTip("Show all the modulations on this track")

	if reaper.ImGui_IsItemHovered(ctx) then
		hovered = true
		if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
			clicked = true
			overview_toggle = true
		end
	end

	reaper.ImGui_SameLine(ctx)			
	local after_x, after_y = reaper.ImGui_GetCursorPos(ctx)		

	if full == 1 then
		reaper.ImGui_PopStyleColor(ctx, 1)
	end

	-- Change option after the button color push/pop
	if overview_toggle then
		full = 1 - full
		reaper.SetProjExtState(0, "vf_flashmob", "overview", full)
	end

	-- Display icon
	reaper.ImGui_SetCursorPos(ctx, before_x + (width * 0.5) - 8, before_y + 2)   
			
	if hovered then
		reaper.ImGui_Image(ctx, img_overview_hover, reaper.ImGui_Image_GetSize(img_overview_hover))   
	elseif full == 1 then
		reaper.ImGui_Image(ctx, img_overview_on, reaper.ImGui_Image_GetSize(img_overview_on))   
	else
		reaper.ImGui_Image(ctx, img_overview_off, reaper.ImGui_Image_GetSize(img_overview_off))   
	end

	reaper.ImGui_SetCursorPos(ctx, after_x, after_y)
end

function FlashmobInstanceSelector(track, title)
	-- Multiple Flashmob instances selector
	if rv_flashmob == true and instance_nb > 1 then 
		-- if title == 1 then
		-- 	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextAlign(), 0.5, 0.5)
		-- 	reaper.ImGui_SeparatorText(ctx, "Instance Selector")
		-- 	reaper.ImGui_PopStyleVar(ctx, 1)
		-- end
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)

		-- Left arrow
		if reaper.ImGui_ArrowButton(ctx, '##left', reaper.ImGui_Dir_Left()) then
			mod_container_table_id = mod_container_table_id - 1
			if mod_container_table_id < 1 then mod_container_table_id = #t_flashmob_id end

			mod_container_id = t_flashmob_id[mod_container_table_id]
			local mod_container_guid = reaper.TrackFX_GetFXGUID(track, mod_container_id)
			reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id .. "," .. mod_container_guid, 1)
			reset_plot_lines = true
			-- Close mod assign lists
			for i=1, 6 do
				_G["modList" .. i] = 0
				_G["modPopup" .. i] = 0
			end	

			CheckIfModIsUsed(track, mod_container_id)
			CheckIfMacroIsUsed(track, mod_container_id)
		end
		ToolTip("Select previous Flashmob instance")
		local arrow_w = reaper.ImGui_GetItemRectSize(ctx)
		reaper.ImGui_SameLine(ctx)					

		-- Flashmob name
		local total_fx = reaper.TrackFX_GetCount(track)
		local rv_flashmob_name, mod_container_name = reaper.TrackFX_GetFXName(track, mod_container_id)
		if rv_flashmob_name then
			-- mod_container_name = mod_container_name:gsub('——', '-') -- Workaround to replace unsupported "2 long dashes" characters with one small dash (used by Flashmob)							
			-- mod_container_name = mod_container_name:gsub('—', '-') -- Workaround to replace unsupported "1 long dashes" characters with one small dash (used by Flashmob)							
			mod_container_name = mod_container_name:gsub('——', '') -- Workaround to remove unsupported "2 long dashes" characters
			mod_container_name = mod_container_name:gsub('—', '') -- Workaround to remove unsupported "1 long dashes" characters
			mod_container_name = mod_container_name:gsub('^ ', '') -- Remove leading space
			mod_container_name = mod_container_name:gsub(' $', '') -- Remove trailing space
			local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx) -- to get the available space (including the potential scrollbar)
			local mod_container_name_clipped = ClipText(mod_container_name, avail_x - (arrow_w * 2))
			local mod_container_name_w, mod_container_name_h = reaper.ImGui_CalcTextSize(ctx, mod_container_name_clipped)				

			local x, y = reaper.ImGui_GetCursorPos(ctx)
			local flashmob_name_pos
			if mod_container_name_clipped ~= mod_container_name then -- Center Flashmob name if space is available
				flashmob_name_pos = x + (avail_x - (arrow_w * 2) - mod_container_name_w - win_padding_x)
			else
				flashmob_name_pos = x + (avail_x - (arrow_w * 2) - mod_container_name_w - win_padding_x) * 0.5
			end
			-- if flashmob_name_pos <= arrow_w + win_padding_x + 4 then flashmob_name_pos = arrow_w + win_padding_x + 4 end

			reaper.ImGui_SetCursorPos(ctx, flashmob_name_pos, y + 3)
			local flashmob_instance_color
			reaper.ImGui_InvisibleButton(ctx, "flashmob_name", mod_container_name_w + 20, mod_container_name_h)
			if reaper.ImGui_IsItemHovered(ctx) then									
				flashmob_instance_color = BrighterColor2(t_color_palette[mod_container_table_id], 0.2)
				if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					if user_os == "Win" then
						StartModalWorkaround("flashmob_inst_alias")
					else						
						local retval, retvals_csv = reaper.GetUserInputs("Rename Flashmob Instance", 1, "New Name, extrawidth=70", mod_container_name)
						if retval then
							local new_name = retvals_csv:match("([^,]+)")
							if new_name ~= "" then
								reaper.TrackFX_SetNamedConfigParm(track, mod_container_id, "renamed_name", new_name)
							end
						end
					end
				end
			else
				flashmob_instance_color = t_color_palette[mod_container_table_id]
			end

			if user_os == "Win" and modal_popup_id == "flashmob_inst_alias" and modal_popup == true then
				local retval, retvals_csv = reaper.GetUserInputs("Rename Flashmob Instance", 1, "New Name", mod_container_name)
				if retval then
					local new_name = retvals_csv:match("([^,]+)")
					if new_name ~= "" then
						reaper.TrackFX_SetNamedConfigParm(track, mod_container_id, "renamed_name", new_name)
					end
				end
				ResetModalWorkaroundVariables()
			end				

			reaper.ImGui_SetCursorPos(ctx, flashmob_name_pos, y + 3)
			reaper.ImGui_PushFont(ctx, fonts.medium_bold)
			reaper.ImGui_TextColored(ctx, flashmob_instance_color, mod_container_table_id .. " - " .. mod_container_name_clipped)
			reaper.ImGui_PopFont(ctx)

			-- local mod_container_name_num = "(" .. mod_container_table_id .. "/" .. #t_flashmob_id .. ") " ..  mod_container_name -- Add the current flashmob instance index							
			local mod_container_name_num = mod_container_name .. " (Flashmob instance " .. mod_container_table_id .. "/" .. #t_flashmob_id .. ") "   -- Add the current flashmob instance index							
			-- if mod_container_name_clipped ~= mod_container_name then ToolTip(mod_container_name_num) end					 
			ToolTip(mod_container_name_num)
		end
		reaper.ImGui_SameLine(ctx)

		-- Right arrow
		local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
		local x, y = reaper.ImGui_GetCursorPos(ctx)
		reaper.ImGui_SetCursorPos(ctx, x + avail_x - arrow_w, y - 3)
		if reaper.ImGui_ArrowButton(ctx, '##right', reaper.ImGui_Dir_Right()) then
			mod_container_table_id = mod_container_table_id + 1
			if mod_container_table_id > #t_flashmob_id then mod_container_table_id = 1 end

			mod_container_id = t_flashmob_id[mod_container_table_id]
			local mod_container_guid = reaper.TrackFX_GetFXGUID(track, mod_container_id)
			reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id .. "," .. mod_container_guid, 1)
			reset_plot_lines = true	
			-- Close mod assign lists
			for i=1, 6 do
				_G["modList" .. i] = 0
				_G["modPopup" .. i] = 0
			end								

			CheckIfModIsUsed(track, mod_container_id)
			CheckIfMacroIsUsed(track, mod_container_id)			
		end	
		ToolTip("Select next Flashmob instance")
		reaper.ImGui_PopStyleVar(ctx, 1)
	end






end

------------------------------------------------------------------------------------
-- MAIN FUNCTIONS
------------------------------------------------------------------------------------

function Init()

	user_os = reaper.GetOS()
	if user_os:match("macOS") or user_os:match("OSX") then
		user_os = "Mac"
	elseif user_os:match("Win") then
		user_os = "Win"
	end

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
		return require 'imgui' '0.9.3.3'
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
	t_previous_param = {}
	t_pm_data = {}
	t_pm_lfo = {}
	t_pm_acs = {}	
	t_color_palette = ColorPalette()
	plots1, plots2, plots3, plots4, plots5, plots6 = nil
	rv_macro1, rv_macro2, rv_macro3, rv_macro4, rv_macro5, rv_macro6, rv_macro7, rv_macro8 = nil
	macro1, macro2, macro3, macro4, macro5, macro6, macro7, macro8 = nil
	macro_baseline1, macro_baseline2, macro_baseline3, macro_baseline4, macro_baseline5, macro_baseline6, macro_baseline7, macro_baseline8 = nil
	-- modPopup1, modPopup2, modPopup3, modPopup4, modPopup5, modPopup6 = nil
	macroPopup1, macroPopup2, macroPopup3, macroPopup4, macroPopup5, macroPopup6, macroPopup7, macroPopup8 = nil
	modUsed = {modUsed1 = nil, modUsed2 = nil, modUsed3 = nil, modUsed4 = nil, modUsed5 = nil, modUsed6 = nil}
	macroUsed = {macroUsed1 = nil, macroUsed2 = nil, macroUsed3 = nil, macroUsed4 = nil, macroUsed5 = nil, macroUsed6 = nil}
	-- child_height1, child_height2, child_height3, child_height4, child_height5, child_height6 = 76
	-- test_1, test_2, test_3, test_4, test_5, test_6 = 0
	UI_color = -1499027713 -- Grey
	white = reaper.ImGui_ColorConvertDouble4ToU32(0.8, 0.8, 0.8, 1)
	full_white = reaper.ImGui_ColorConvertDouble4ToU32(1, 1, 1, 1)	
	grey = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 0.8)	
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
	macro_mod_enable = 0
	help_page = 0
	settings_page = 0
	modal_popup_prepare = nil -- Disable ImGui window on top of all other windows on PC when Reaper native modals are going to open next frame
	wait1Frame = nil
	modal_popup = nil -- Open Reaper native modal after TopMost window flag have been disabled
	modal_popup_id = ""
	t_fxchains = {}

	-- Load Images	
	img_lock_off = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Lock_off.png")
	reaper.ImGui_Attach(ctx, img_lock_off) -- img is attached to survive multiple frames even if not used in the current frame
	img_lock_hover = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Lock_hover.png")
	reaper.ImGui_Attach(ctx, img_lock_hover)
	img_lock_on = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Lock_on.png")
	reaper.ImGui_Attach(ctx, img_lock_on)
	img_macroMod_off = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "MacroMod_off.png")
	reaper.ImGui_Attach(ctx, img_macroMod_off)	
	img_macroMod_hover = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "MacroMod_hover.png")
	reaper.ImGui_Attach(ctx, img_macroMod_hover)	
	img_macroMod_on = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "MacroMod_on.png")
	reaper.ImGui_Attach(ctx, img_macroMod_on)
	img_macroMod_off_disabled = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "MacroMod_off_disabled.png")
	reaper.ImGui_Attach(ctx, img_macroMod_off_disabled)	
	img_addInst_off = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "AddInstance_off.png")
	reaper.ImGui_Attach(ctx, img_addInst_off)
	img_addInst_hover = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "AddInstance_hover.png")
	reaper.ImGui_Attach(ctx, img_addInst_hover)	
	img_help_off = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Help_off.png")
	reaper.ImGui_Attach(ctx, img_help_off)
	img_help_hover = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Help_hover.png")
	reaper.ImGui_Attach(ctx, img_help_hover)
	img_help_on = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Help_on.png")
	reaper.ImGui_Attach(ctx, img_help_on)	
	img_settings_off = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Settings_off.png")
	reaper.ImGui_Attach(ctx, img_settings_off)
	img_settings_hover = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Settings_hover.png")
	reaper.ImGui_Attach(ctx, img_settings_hover)
	img_settings_on = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Settings_on.png")
	reaper.ImGui_Attach(ctx, img_settings_on)
	img_overview_off = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Overview_off.png")
	reaper.ImGui_Attach(ctx, img_overview_off)
	img_overview_hover = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Overview_hover.png")
	reaper.ImGui_Attach(ctx, img_overview_hover)
	img_overview_on = reaper.ImGui_CreateImage(script_path .. "Icons/" .. "Overview_on.png")
	reaper.ImGui_Attach(ctx, img_overview_on)						

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

	-- Restore overview state
	local _, saved_overview = reaper.GetProjExtState(0, "vf_flashmob", "overview")	
	if saved_overview ~= "" then
		full = tonumber(saved_overview)
	else
		full = 0
	end



	-- Global settings
	setting_track_control = reaper.GetExtState("vf_flashmob", "track_control")
	if setting_track_control == "" then setting_track_control = 0 else setting_track_control = tonumber(setting_track_control) end

	setting_tooltip = reaper.GetExtState("vf_flashmob", "tooltip")	
	if setting_tooltip == "" then setting_tooltip = 1 else setting_tooltip = tonumber(setting_tooltip) end	

	-- Init Sidechain setting
	setting_sidechain = 0

	-- Default FXChain Preset	
	t_fxchains = GetFXChainsList()

	setting_default_preset = reaper.GetExtState("vf_flashmob", "default_preset")	
	if setting_default_preset == "" then
		setting_default_preset = "Flashmob_Demo"
	end

	for i=1, #t_fxchains do
		if t_fxchains[i] == setting_default_preset then
			current_preset = i - 1
			default_preset = t_fxchains[i]
			break
		end
	end
	if not default_preset then default_preset = "Flashmob_Demo" end

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
				for i=1, 6 do
					_G["modList" .. i] = 0
					_G["modPopup" .. i] = 0
				end

				if mod_container_id then
					CheckIfModIsUsed(track, mod_container_id)
					CheckIfMacroIsUsed(track, mod_container_id)
				end												
			end
			last_track = track
		end  

		rv_flashmob, t_flashmob_id, t_flashmob_guid, flashmob_is_invalid = GetFlashmobInstances(track, flashmob_identifier)		

		if rv_flashmob == true then
			if not mod_container_id then mod_container_id = t_flashmob_id[1] end						
			if not mod_container_guid then mod_container_guid = t_flashmob_guid[1] end			
			if not mod_container_table_id then mod_container_table_id = 1 end

			-- Support multiple instance of Flashmob (on each track with multiple instances, the last selected instance is stored to be recalled when re-selected)
			instance_nb = #t_flashmob_id
			if instance_nb > 1 then 

				local choose_first_instance
				local _, stored_instance = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 0)
				if stored_instance ~= "" then
					local instance_id = stored_instance:gsub("^(%d+).*", "%1")		
					local instance_table_id = stored_instance:gsub("^%d+,(%d+).*", "%1")					
					instance_id = tonumber(instance_id)
					instance_table_id = tonumber(instance_table_id)	
					if proj_updated then				
						if CheckIfStoredInstanceExist(track, flashmob_identifier, instance_id) then
							mod_container_id = instance_id
							mod_container_table_id = instance_table_id								
						else
							local instance_guid = stored_instance:gsub("%d+,%d+,(.*)", "%1")
							
							-- Check if Flashmob instance still exists and get update its fx_index if it was changed
							local doNotExist = true
							for i=1, #t_flashmob_guid do
								local guid = t_flashmob_guid[i]
								if guid == instance_guid then
									mod_container_id = t_flashmob_id[i]
									mod_container_table_id = i
									doNotExist = false
									break
								end
							end
							if doNotExist == true then
								choose_first_instance = true
							end
						end
					end
				else
					choose_first_instance = true
				end		
				if choose_first_instance == true then
					mod_container_id = t_flashmob_id[1]	
					mod_container_table_id = 1	
					mod_container_guid = t_flashmob_guid[1]		
					-- reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 1)	
					reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", mod_container_id .. "," .. mod_container_table_id .. "," .. mod_container_guid, 1)
				end
			else
				mod_container_id = t_flashmob_id[1]
				mod_container_table_id = 1	
				reaper.GetSetMediaTrackInfo_String(track, "P_EXT:vf_flashmob_last_instance", "", 1)
			end
		else
			instance_nb = 0
			setting_sidechain = 0
		end

		if first_run or project_switched or (param_lock == 0 and (track_sel_changed or slower_defer_update or proj_updated)) then

			if rv_flashmob == true then
				GetSidechain(track, mod_container_id) -- Get current Flashmob routing
				SetFlashmobRouting(track, mod_container_id, setting_sidechain) -- Set current Flashmob instance routing based on Sidechain settings
			end
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
		if track_name_clipped ~= track_name then ToolTip(track_name, 1) end		

		-- Draw small x button to close the window
		if reaper.ImGui_IsMouseHoveringRect(ctx, rect_x - win_padding_x, rect_y - win_padding_y, rect_x + width, rect_y + height) then
			local x_color = reaper.ImGui_ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 0.3)

			reaper.ImGui_SetCursorScreenPos(ctx, rect_x + width - 28, rect_y - 6)
			if reaper.ImGui_IsMouseHoveringRect(ctx, rect_x + width - 28, rect_y - 4, rect_x + width - 28 + 18, rect_y - 4 + text_h + 4) then
				x_color = reaper.ImGui_ColorConvertDouble4ToU32(0, 0, 0, 1)
				reaper.ImGui_DrawList_AddCircleFilled(draw_list, rect_x + width - 24, rect_y + 2, 8, x_color, 20)
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), white)
				reaper.ImGui_Text(ctx, "x")
				reaper.ImGui_PopStyleColor(ctx, 1)	
				if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
					open = false
				end
			else
				reaper.ImGui_DrawList_AddCircleFilled(draw_list, rect_x + width - 24, rect_y + 2, 8, x_color, 20)
				reaper.ImGui_Text(ctx, "x")
			end			
		end			
		reaper.ImGui_PopStyleColor(ctx, 1)			
		reaper.ImGui_PopFont(ctx)

		reaper.ImGui_SetCursorPos(ctx, x, y)		

		-- Various Icons
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)			
		reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 1)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), track_color)
		reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), track_color)

		reaper.ImGui_SetCursorPosX(ctx, 0)
		local button_nb = 5
		local button_width = (width - 5) / button_nb
		for i=1, button_nb do
			CustomButton(ctx, i, button_nb, button_width, 20, track, t_last_param.fx, t_last_param.param)
		end
		reaper.ImGui_PopStyleColor(ctx, 2)
		reaper.ImGui_PopStyleVar(ctx, 3)

		local function SeparatorColor()
			local separator_color
			if track_color == UI_color then
				separator_color = full_white
			else
				separator_color = track_color
			end
			return separator_color
		end

		if help_page == 1 then
			local width = width - 16
			if reaper.ImGui_BeginChild(ctx, "help_page", width, height - 50) then	
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_PushFont(ctx, fonts.medium_bold)	
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), SeparatorColor())
				reaper.ImGui_SeparatorText(ctx, "Quick Start Guide")
				reaper.ImGui_PopStyleColor(ctx, 1)
				reaper.ImGui_PopFont(ctx)
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_PushFont(ctx, fonts.medium_small_bold)
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), white)
				reaper.ImGui_PushTextWrapPos(ctx, 0)
				reaper.ImGui_Text(ctx, "1. Enable Flashmob on a track.")
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_Text(ctx, "2. Touch any other plugin FX parameter on this track.")
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_Text(ctx, "3. You now have 3 options to modulate this parameter:\n\tA - Khs SNAPHEAP modulation\n\t(require Khs Snapheap plugin)\n\tB - Flashmob MACRO\n\tC - Reaper NATIVE modulation")				
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_Text(ctx, "4. For SNAPHEAP MODS and MACROS, select the wanted tab and click on their name to create a mapping.")
				reaper.ImGui_Text(ctx, "To adjust the amount of modulation, tweak the AMOUNT SLIDER in the LAST FX PARAM section.")
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_Text(ctx, "5. For NATIVE modulations, select the NATIVE tab and activate modules.")
				reaper.ImGui_Text(ctx, "To adjust the amount of modulation, tweak the STRENGTH slider in the NATIVE tab section.")
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_TextColored(ctx, t_color_palette[5], "IMPORTANT:")
				reaper.ImGui_Text(ctx, "An FX parameter cannot be mapped to a Snapheap mod AND a macro at the same time.")
				reaper.ImGui_Text(ctx, "NATIVE modulation however, can be combined with anything.")
				-- reaper.ImGui_Text(ctx, "3.1.a To modulate the last-touched FX parameter with a NATIVE modulation, click on the NATIVE tab and activate the LFO, the ACS or the MIDI LEARN")
				-- reaper.ImGui_Text(ctx, "3.1.b To adjust the amount of NATIVE modulation, tweak the STRENGTH slider")
				-- reaper.ImGui_Text(ctx, "3.2.a To map the last-touched FX parameter to a MACRO, click on the MACRO tab then click on a macro name")
				-- reaper.ImGui_Text(ctx, "3.2.b To adjust the range of the MACRO for this FX parameter, tweak the MACRO AMOUNT slider in the LAST FX PARAM section")
				-- reaper.ImGui_Text(ctx, "3.3.a To map the last-touched FX parameter to a SNAPHEAP modulation, click on the MODS tab then click on a mod name")
				-- reaper.ImGui_Text(ctx, "3.3.b To adjust the amount of SNAPHEAP modulation for this FX parameter, tweak the MOD AMOUNT slider in the LAST FX PARAM section")
				-- reaper.ImGui_Text(ctx, "3.3.c To EDIT the SNAPHEAP modulation signal, click on the MOD graph. It would open SNAPHEAP.")
				-- reaper.ImGui_Text(ctx, "3.3.d Map SNAPHEAP modulators to the bus 1 or 2 GAIN effect. This is the FUN part!")			
				reaper.ImGui_PopTextWrapPos(ctx)
				reaper.ImGui_PopStyleColor(ctx, 1)
				reaper.ImGui_PopFont(ctx)

				reaper.ImGui_Dummy(ctx, 0, 10)
				local button_pos_x = (width * 0.5) - ((width * 0.75) * 0.5)
				local button_width = width * 0.75
				local flashmob_manual_text = "Flashmob Manual"
				local flashmob_manual_text_clipped = ClipText(flashmob_manual_text, button_width - win_padding_x)

				reaper.ImGui_SetCursorPosX(ctx, button_pos_x)
				if reaper.ImGui_Button(ctx, flashmob_manual_text_clipped, button_width, 30) then
					OpenURL("https://www.vincentfliniaux.com")
				end
				if flashmob_manual_text_clipped ~= flashmob_manual_text then ToolTip(flashmob_manual_text, 1) end

				reaper.ImGui_Dummy(ctx, 0, 0)
				local snapheap_tuto_text = "Snapheap Tutorials"
				local snapheap_tuto_text_clipped = ClipText(snapheap_tuto_text, button_width - win_padding_x)

				reaper.ImGui_SetCursorPosX(ctx, button_pos_x)
				if reaper.ImGui_Button(ctx, snapheap_tuto_text_clipped, button_width, 30) then
					OpenURL("https://youtube.com/playlist?list=PLXyyKlK7qpvUOJSzJEK0yRn1JhNJAtTxE&si=GDM0jt3mVnoAkFbQ")
				end
				if snapheap_tuto_text_clipped ~= snapheap_tuto_text then ToolTip(snapheap_tuto_text, 1) end

				reaper.ImGui_Dummy(ctx, 0, 0)
				local ask_questions_text = "Ask Questions"
				local ask_questions_text_clipped = ClipText(ask_questions_text, button_width - win_padding_x)

				reaper.ImGui_SetCursorPosX(ctx, button_pos_x)
				if reaper.ImGui_Button(ctx, ask_questions_text_clipped, button_width, 30) then
					-- Open forum thread link
				end	
				if ask_questions_text_clipped ~= ask_questions_text then ToolTip(ask_questions_text, 1) end

				reaper.ImGui_Dummy(ctx, 0, 0)
				local support_me_text = "Support Me"
				local support_me_text_clipped = ClipText(support_me_text, button_width - win_padding_x)

				reaper.ImGui_SetCursorPosX(ctx, button_pos_x)
				if reaper.ImGui_Button(ctx, support_me_text_clipped, button_width, 30) then
					-- Open Donate link
				end	
				if support_me_text_clipped ~= support_me_text then ToolTip(support_me_text, 1) end

				reaper.ImGui_EndChild(ctx)
			end							

		elseif settings_page == 1 then

			rv_flashmob, t_flashmob_id, t_flashmob_guid, flashmob_is_invalid = GetFlashmobInstances(track, flashmob_identifier)

			local width = width - 16
			if reaper.ImGui_BeginChild(ctx, "settings_page", width, height - 50) then
				reaper.ImGui_Dummy(ctx, 0, 0)
				reaper.ImGui_PushFont(ctx, fonts.medium_bold)	
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), SeparatorColor())					
				reaper.ImGui_SeparatorText(ctx, "Global Overview")
				reaper.ImGui_PopStyleColor(ctx, 1)
				reaper.ImGui_PopFont(ctx)
				reaper.ImGui_Dummy(ctx, 0, 0)

				if reaper.ImGui_Checkbox(ctx, "Tooltip", setting_tooltip) then
					if setting_tooltip == 1 then 
						setting_tooltip = 0 
					else 
						setting_tooltip = 1
					end
					reaper.SetExtState("vf_flashmob", "tooltip", setting_tooltip, 1)					
				end					
				ToolTip("If enabled, display additional info when hovering the mouse over \nvarious UI elements", 1)

				local track_control_text = "Reaper Track Control"
				local track_control_text_clipped = ClipText(track_control_text, width - 22)
				if reaper.ImGui_Checkbox(ctx, track_control_text_clipped, setting_track_control) then
					if setting_track_control == 1 then 
						setting_track_control = 0 
					else 
						setting_track_control = 1
					end
					reaper.SetExtState("vf_flashmob", "track_control", setting_track_control, 1)					
				end					
				ToolTip("If enabled, FX parameters mapped to SNAPHEAP or NATIVE modulations \nare visible as Reaper Track Control (TCP and MCP)", 1)
				reaper.ImGui_Dummy(ctx, 0, 8)

				reaper.ImGui_PushFont(ctx, fonts.medium_bold)	
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), SeparatorColor())					
				reaper.ImGui_SeparatorText(ctx, "Instance Overview")
				reaper.ImGui_PopStyleColor(ctx, 1)
				reaper.ImGui_PopFont(ctx)
				reaper.ImGui_Dummy(ctx, 0, 0)

				if not rv_flashmob then
					reaper.ImGui_BeginDisabled(ctx)
				end				

				-- Multiple Flashmob instances selector
				FlashmobInstanceSelector(track)
				reaper.ImGui_Dummy(ctx, 0, 0)

				local sidechain_text = "Follower Sidechain"
				local sidechain_text_clipped = ClipText(sidechain_text, width - 22)
				if reaper.ImGui_Checkbox(ctx, sidechain_text_clipped, setting_sidechain) then
					if setting_sidechain == 1 then 
						setting_sidechain = 0 
					else 
						setting_sidechain = 1
					end
					ToggleSidechain(track, mod_container_id)					
				end	

				ToolTip("If enabled, Snapheap audio follower will listen to the sidechain \nsignal (3/4) instead of the main signal)", 1)				

				if not rv_flashmob then
					reaper.ImGui_EndDisabled(ctx)
				end
				reaper.ImGui_Dummy(ctx, 0, 8)

				reaper.ImGui_PushFont(ctx, fonts.medium_bold)
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), SeparatorColor())						
				reaper.ImGui_SeparatorText(ctx, "Default Preset")
				reaper.ImGui_PopStyleColor(ctx, 1)
				reaper.ImGui_PopFont(ctx)
				reaper.ImGui_Dummy(ctx, 0, 0)

				-- reaper.ImGui_Text(ctx, "Default Preset")
				-- reaper.ImGui_SameLine(ctx)
				-- reaper.ImGui_TextDisabled(ctx, "(?)")
				-- ToolTip("Set the default Flashmob preset when adding an instance.\nYou can save other presets by saving Flashmob containers\nas FX chains in the Flashmob Preset Location below.", 1)				

				local button_pos_x = (width * 0.5) - ((width * 0.75) * 0.5)
				local button_width = width * 0.75
				local preset_loc_text = "Open Presets Location"
				local preset_loc_text_clipped = ClipText(preset_loc_text, button_width - win_padding_x)

				reaper.ImGui_SetCursorPosX(ctx, button_pos_x)
				if reaper.ImGui_Button(ctx, preset_loc_text_clipped, button_width, 30) then
					if user_os == "Mac" then
						os.execute('open "' .. script_path .. 'FXChains"')
					elseif user_os == "Win" then
						os.execute('start "" "' .. script_path .. 'FXChains"')
					end
				end
				if preset_loc_text_clipped ~= preset_loc_text then ToolTip(preset_loc_text, 1) end

				reaper.ImGui_Dummy(ctx, 0, 0)

				if slower_defer_update then -- refresh the first frame settings page is open
					t_fxchains = GetFXChainsList()
					-- If FXCHain is missing, set the first one as the default one.
					if not reaper.file_exists(script_path .. "FXChains/" .. default_preset .. ".RfxChain") then
						current_preset = 0
						if t_fxchains[1] then
							default_preset = t_fxchains[1]
						else
							default_preset = "Flashmob_Demo" -- Will trigger an "controlled" error when adding Flashmob as the FXChains folder is empty. It's normal.
						end
						reaper.SetExtState("vf_flashmob", "default_preset", default_preset, 1)
					else
						for i=1, #t_fxchains do
							if t_fxchains[i] == default_preset then
								current_preset = i - 1
								break
							end
						end	
					end					
				end

				flashmob_presets = table.concat(t_fxchains, "\0") .. "\0" -- Convert table into a null-terminated string for the ListBox object

				if not current_preset then
					current_preset = 0 				
				end

				if t_fxchains[1] then -- If FXChains folder is not empty
					reaper.ImGui_SetNextItemWidth(ctx, width)
					rv_default_preset, current_preset = reaper.ImGui_ListBox(ctx, "##Default_Preset_List", current_preset, flashmob_presets, 8)
					if rv_default_preset then
						default_preset = t_fxchains[current_preset + 1]
						reaper.SetExtState("vf_flashmob", "default_preset", default_preset, 1)
					end
				end

				reaper.ImGui_TextDisabled(ctx, "(More info)")
				ToolTip("Set the default Flashmob preset when adding an instance.\nYou can save other presets by saving Flashmob containers\nas FX chains in the Flashmob presets location above.", 1)

				reaper.ImGui_EndChild(ctx)
			end
		else				

			-- if rv_flashmob == true then			
				if reload_settings  == true then				
					if header_state_param == 1 then
						custom_headers["Header_Param"] = true
					else
						custom_headers["Header_Param"] = false
					end	
				end	

				local header_state_param
				reaper.ImGui_PushFont(ctx, fonts.medium_bold)	
				reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 1)

				local header_name = "LAST FX PARAM"
				header_name = ClipText(header_name, width - win_padding_x)							
				local previous_x, previous_y = reaper.ImGui_GetCursorPos(ctx)			

				custom_headers["Header_Param"] = CustomCollapsingHeader(ctx, "Header_Param", header_name, width, 20, 0)
				local x, y = reaper.ImGui_GetCursorPos(ctx)				

				reaper.ImGui_PopStyleVar(ctx)
				reaper.ImGui_PopFont(ctx)
				-- if header_param then
				if custom_headers["Header_Param"] then	
					header_state_param = 1
					reaper.ImGui_SetCursorPos(ctx, x, y) -- Restore position after Header (instead of using the position of the overlapping text)								
					local fx_param_child_size
					if rv_flashmob == true then
						fx_param_child_size = 105
					else
						fx_param_child_size = 66
					end
					if reaper.ImGui_BeginChild(ctx, 'FX Param', 0, fx_param_child_size, child_flags, window_flags) then -- Set a fixed size for the FX parameter space
						reaper.ImGui_Dummy(ctx, 0, 0)				
						if param_is_valid == true then -- If there is a valid last touched parameter				

							-- PARAMETER NAME & NATIVE MOD ICONS
							reaper.ImGui_PushFont(ctx, fonts.medium_bold)
							local param_name = t_last_param.param_name

							local param_name_w, param_name_h = reaper.ImGui_CalcTextSize(ctx, param_name)
							local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
							local param_name_hovering = reaper.ImGui_IsMouseHoveringRect(ctx, x, y, x + (width * 0.4), y + param_name_h + 4)

							reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 4, 4)						

							-- Native LFO icon
							-- if (param_name_hovering or (t_pm_data.lfo_active and t_pm_data.lfo_active == 1)) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then 					
							if (param_name_hovering or (t_pm_data.lfo_active and t_pm_data.lfo_active == 1)) then 					
								DrawIcon(15, 12, track_color, track, t_last_param.fx, t_last_param.param, t_pm_data.lfo_active, 1) -- LFO
								reaper.ImGui_SameLine(ctx)						
							end

							-- Native ACS icon
							-- if (param_name_hovering or t_pm_data.acs_active and t_pm_data.acs_active == 1) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then
							if (param_name_hovering or t_pm_data.acs_active and t_pm_data.acs_active == 1) then
								DrawIcon(15, 12, track_color, track, t_last_param.fx, t_last_param.param, t_pm_data.acs_active, 2) -- ACS
								reaper.ImGui_SameLine(ctx)
							end	
							reaper.ImGui_PopStyleVar(ctx, 1)							

							-- MIDI Learn
							local midi_learn_state
							if t_pm_data.midi_learn and t_pm_data.midi_learn ~= 0 then
								midi_learn_state = t_pm_data.midi_learn and 1 or 0
							else
								midi_learn_state = 0
							end
							-- if (param_name_hovering or t_pm_data.midi_learn) and (t_pm_data.mod_active == nil or t_pm_data.mod_active == 1) then
							if param_name_hovering or (t_pm_data.midi_learn and t_pm_data.midi_learn ~= 0) then
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
							if param_name_clipped ~= param_name then ToolTip(param_name,1) end

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
								-- if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Super()) then
								if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
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
							if (param_link == 1 or param_link == 2 or t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1) and t_pm_data.mod_active == 1 then
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
								if rv_flashmob == true and t_last_param.fx == mod_container_id and t_last_param.param < 8 then
									last_touched_param_value = string.format("%.2f", last_touched_param_value)
								end
								reaper.ImGui_Text(ctx, last_touched_param_value)
							end			
							reaper.ImGui_PopFont(ctx)			

							-- SLIDERS

							-- Calculate slider mod range 
							if rv_link_scale or rv_baseline or lfo_strength_adjust or acs_strength_adjust or overview_scale or overview_baseline then -- If sliders are adjusted, freeze the mod range to its max for a better visualization
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
							if rv_flashmob == true then
								local show_mod_slider
								if reaper.ImGui_IsWindowDocked(ctx) then
									if param_link > -1 then -- If last touched parameter is linked
										show_mod_slider = 1
									end
								else
									show_mod_slider = 1
								end
								if show_mod_slider == 1 then															
									local mod_amount_text_color = DarkerColor2(full_white, 0.2)

									if param_link > -1 and param_link < 2 then -- If last touched parameter is linked to the selected Flashmob instance (no matter if its activated or not)
										reaper.ImGui_PushFont(ctx, fonts.medium_bold)

										local amount_pre_text
										if t_pm_data.link_source_param > 7 then
											amount_pre_text = "Mod"
										else
											amount_pre_text = "Macro"
										end
										local full_text = amount_pre_text .. " 1 " .. "amount"
										local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, full_text)


										-- Set the amount text color (darker if modulation is disabled)
										if t_pm_data.link_active == nil or t_pm_data.link_active == 0 then
											mod_amount_text_color = DarkerColor2(full_white, 0.7)	
										end

										-- Highlight text when mouse hovering
										local rect_x, rect_y = reaper.ImGui_GetCursorScreenPos(ctx)
										if reaper.ImGui_IsMouseHoveringRect(ctx, rect_x, rect_y + 8, rect_x + text_w + 11, rect_y + 6 + text_h, clipIn) then
											mod_amount_text_color = BrighterColor2(mod_amount_text_color, 0.2)
										end	

										-- Get linked modulator index (mod or macro)
										local mod_index
										if t_pm_data.link_source_param > 7 then
											mod_index = t_pm_data.link_source_param - 7 -- Hard-coded number of modulators (0-based)
										else
											mod_index = t_pm_data.link_source_param + 1 -- Hard-coded number of macros (0-based)
										end

										-- Display Mod amount text line
										-- Add a pixel of separation with the UI above
										local x_sep, y_sep = reaper.ImGui_GetCursorScreenPos(ctx)
										reaper.ImGui_SetCursorScreenPos(ctx, x_sep, y_sep + 1)								
										reaper.ImGui_Dummy(ctx, 0, 0)

										-- Display mod or macro word
										reaper.ImGui_BeginGroup(ctx)
										reaper.ImGui_TextColored(ctx, mod_amount_text_color, amount_pre_text)

										-- Display mod number in a circle or a square
										reaper.ImGui_SameLine(ctx)	
										local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
										local center_x, center_y = reaper.ImGui_GetCursorScreenPos(ctx)

										if t_pm_data.link_source_param > 7 then										
											reaper.ImGui_DrawList_AddCircle(draw_list, center_x + 4, center_y + 6, 8, t_color_palette[mod_index], num_segmentsIn, thicknessIn)
										else
											reaper.ImGui_DrawList_AddRect(draw_list, center_x - 4, center_y - 2, center_x + 12, center_y + 14, t_color_palette[mod_container_table_id], roundingIn, flagsIn, thicknessIn)
											-- reaper.ImGui_DrawList_AddCircle(draw_list, center_x + 4, center_y + 6, 8, UI_color, num_segmentsIn, thicknessIn)
										end

										if t_pm_data.link_source_param > 7 then
											reaper.ImGui_TextColored(ctx, t_color_palette[mod_index], mod_index)
										else
											reaper.ImGui_TextColored(ctx, t_color_palette[mod_container_table_id], mod_index)
										end

										-- Display amount word
										reaper.ImGui_SameLine(ctx)	
										reaper.ImGui_TextColored(ctx, mod_amount_text_color, "Amount")
										reaper.ImGui_EndGroup(ctx)
										
										-- reaper.ImGui_PopStyleColor(ctx, 1)
										-- ToolTip("Left-click: Enable/disable modulation\nAlt-click: Delete modulation")
										if t_pm_data.link_source_param > 7 then										
											ToolTip("Left-click: Open/close Snapheap\nRight-click: Enable/disable modulation\nAlt-click: Delete modulation")
										else
											ToolTip("Right-click: Enable/disable modulation\nAlt-click: Delete modulation")
										end

										local unlink_confirmed
										if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then

											-- Delete modulation (while holding ALT)
											if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
												if user_os == "Win" then
													StartModalWorkaround("remove_mapping")
												else	
													local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
													if user_input_remove_mapping == 6 then -- YES
														unlink_confirmed = true
													end	
												end

											else
												if rv_flashmob == true and t_pm_data.link_source_param > 7 then
													local index = 1
													if t_pm_data.link_source_param > 7 and t_pm_data.link_source_param <= 9 then index = 1 end
													if t_pm_data.link_source_param > 9 and t_pm_data.link_source_param <= 11 then index = 3 end											
													if t_pm_data.link_source_param > 11 and t_pm_data.link_source_param <= 13 then index = 5 end																						
													OpenSnapheap(track, mod_container_id, index)
												end
											end
										end

										-- Logic to active or de-active modulation											
										if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Right()) then
											if t_pm_data.link_active == 0 then	  
												t_pm_data.link_active = 1
												reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. t_last_param.param .. ".plink.active", 1)
											else
												t_pm_data.link_active = 0
												reaper.TrackFX_SetNamedConfigParm(track, t_last_param.fx, "param." .. t_last_param.param .. ".plink.active", 0)
												reaper.TrackFX_SetParam(track, t_last_param.fx, t_last_param.param, t_pm_data.baseline)
											end
										end										


										if user_os == "Win" and modal_popup_id == "remove_mapping" and modal_popup == true then
											local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove the mapping?", "REMOVE MAPPING?", 4)
											if user_input_remove_mapping == 6 then -- YES
												unlink_confirmed = true
											end			
											ResetModalWorkaroundVariables()
										end										

										if unlink_confirmed == true then									
											UnlinkParam(track, t_last_param.fx, t_last_param.param)
										end

										-- Get MOD or MACRO color
										local mod_slider_color
										if t_pm_data.link_source_param > 7 then
											mod_slider_color = t_color_palette[mod_index]
										else
											-- mod_slider_color = UI_color
											mod_slider_color = t_color_palette[mod_container_table_id]
										end	

										-- Show mod amount value of 0% in blinking RED if no mod amount to give a clear feedback to the user									
										local time = reaper.time_precise()
										local blink_interval = 0.75 -- seconds
										local mod_amount_value_color
										if t_pm_data.link_source_param > 7 then
											mod_amount_value_color = t_color_palette[mod_index]										
										else
											mod_amount_value_color = UI_color
										end						

										-- show mod range value text (while adjusting mod amount slider)
										if t_pm_data.link_active and t_pm_data.link_active == 1 then
											if show_mod_value == true or (t_pm_data.link_scale and t_pm_data.link_scale	== 0 and (time % (blink_interval * 2)) < blink_interval) then
												reaper.ImGui_SameLine(ctx)		
												reaper.ImGui_TextColored(ctx, mod_amount_value_color, string.format('%.1f %%', t_pm_data.link_scale*100))
											end	
										end

										rv_link_scale, t_pm_data.link_scale = CustomSlider("Amount", t_pm_data.link_scale, 0, -1, 1, custom_widget_width, 13, 0, false, t_pm_data.link_active, 0, mod_slider_color, 1)
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
										local amount_error_text_color

										-- Set text color
										if param_link == -1 then
											amount_error_text_color = DarkerColor2(full_white, 0.7)
										else
											amount_error_text_color = DarkerColor2(full_white, 0.2)
										end

										if param_link == -1 then
											text_param_link = "No Link Modulation"
										elseif param_link == 2 then
											text_param_link = "Linked to another Flashmob"
										elseif param_link == 3 then
											text_param_link = "Linked to external parameter"
										end

										-- Add 1 pixel in y
										local x, y = reaper.ImGui_GetCursorPos(ctx)
										reaper.ImGui_SetCursorPosY(ctx, y + 1)

										text_param_link_clipped = ClipText(text_param_link, width - win_padding_x * 2)
										reaper.ImGui_TextColored(ctx, amount_error_text_color, text_param_link_clipped)
										if text_param_link_clipped ~= text_param_link then ToolTip(text_param_link, 1) end							

										-- Dummy slider (to keep the window size and avoid constant annoying redrawing)
										local rv_dummy, dummy
										if not dummy then dummy = 0 end
										rv_dummy, dummy = CustomSlider("Dummy", dummy, 0, -1, 1, custom_widget_width, 13, 0, false, 0, 0, UI_color)								
									end
									-- reaper.ImGui_PopStyleColor(ctx, 1)
								end
							end

							reaper.ImGui_Dummy(ctx, 0, 0)
						else
							reaper.ImGui_PushFont(ctx, fonts.medium)
							local text_no_param
							if result == -1 then
								-- text_no_param = "No last touched FX parameter detected"
								text_no_param = "To start, touch an FX parameter on this track"
							elseif result == -5 then
								text_no_param = "FX in FX container are not supported yet"					
							elseif result == -2 then
								text_no_param = "Input FX are not supported"
							elseif result == -3 then
								text_no_param = "Take FX are not supported"
							else
								-- text_no_param = "The last touched FX parameter isn't tied to the track"
								text_no_param = "To start, touch an FX parameter on this track"
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
				local header_name_source = "MOD SOURCES"	
				if full == 1 then header_name_source = "OVERVIEW" end		
				header_name_source = ClipText(header_name_source, width - win_padding_x)			
				local previous_x, previous_y = reaper.ImGui_GetCursorPos(ctx)			

				local header_rounding
				if custom_headers["Header_Source"] == false then header_rounding = 9 else header_rounding = 0 end

				local x, y = reaper.ImGui_GetCursorPos(ctx)	
				reaper.ImGui_SetCursorPos(ctx, x, y + 1)

				custom_headers["Header_Source"] = CustomCollapsingHeader(ctx, "Header_Source", header_name_source, width - (width / 5), 20, header_rounding)

				local x, y = reaper.ImGui_GetCursorPos(ctx)				

				-- Overview Icon				
				reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)
				reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)			
				reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 1)
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), track_color)
				reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), track_color)

				reaper.ImGui_SameLine(ctx)
				reaper.ImGui_SetCursorPos(ctx, width - (width / 5) + 1, y - 20)
				OverviewButton(ctx, width / 5 - 1, 20, track)
				reaper.ImGui_PopStyleColor(ctx, 2)
				reaper.ImGui_PopStyleVar(ctx, 3)

				reaper.ImGui_SetCursorPos(ctx, x, y)

				reaper.ImGui_PopFont(ctx)
				if custom_headers["Header_Source"] then									
					header_state_source = 1
					reaper.ImGui_SetCursorPos(ctx, x, y) -- Restore position after Header (instead of using the position of the overlapping text)				
					local visible = reaper.ImGui_BeginChild(ctx, 'Mod', 0, height - y - 8, child_flags, window_flags) -- -32 is hard-coded and should be improved to be dynamic
					if visible then	
						reaper.ImGui_Dummy(ctx, 0, 0)	

						if rv_flashmob == true then	
							-- Multiple Flashmob instances selector
							FlashmobInstanceSelector(track, 1)					

							if not flashmob_is_invalid then
								-- Calcule Mod Graph Data here to be able to switch tabs without interupting the graphs
								for i=1, 6 do
									ModGraphData(track, mod_container_id, i)
								end
							end	
						end

						-- Active macro mod when overview is enabled
						if full == 1 then
							if not previous_macro_mod_enable_overview then
								previous_macro_mod_enable_overview = macro_mod_enable
								macro_mod_enable = 1
							end
						else				
							if previous_macro_mod_enable_overview then			
								macro_mod_enable = previous_macro_mod_enable_overview
								previous_macro_mod_enable_overview = nil
							end
						end	

						if full == 1 then 
							-- reaper.ImGui_Dummy(ctx, 0, 0)
							local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
							reaper.ImGui_BeginChild(ctx, "Full", size_wIn, size_hIn, borderIn, reaper.ImGui_ChildFlags_AutoResizeY()) -- To restrict the scrollbar to the mod tab content						
							reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), 1)	
							reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 6)
							local child_border_col
							if track_color == UI_color then
								child_border_col = white
							else
								child_border_col = track_color
							end
							reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor2(UI_color, 0.3))						
							t_overview = GetOverview(track)

							lfo_strength_adjust = nil							
							acs_strength_adjust = nil	
							overview_baseline = nil
							overview_scale = nil	
							hover_lfo = nil
							hover_acs = nil					

							-- Count how many lines are gonna be displayed to calculate the child height
							local counts = {}
							local counts_line = {}
							for _, it in ipairs(t_overview) do
								counts[it.fx_id] = (counts[it.fx_id] or 0) + 1
								if not counts_line[it.fx_id] then counts_line[it.fx_id] = 0 end
								if it.link_active == 1 then counts_line[it.fx_id] = counts_line[it.fx_id] + 1 end
								if it.lfo_active == 1 then counts_line[it.fx_id] = counts_line[it.fx_id] + 1 end
								if it.acs_active == 1 then counts_line[it.fx_id] = counts_line[it.fx_id] + 1 end
								if it.midi_learn and it.midi_learn ~= 0 then counts_line[it.fx_id] = counts_line[it.fx_id] + 1 end
							end							

							local last_fx = nil
							local child_open = false

							local avail = reaper.ImGui_GetContentRegionAvail(ctx)							

							for i=1, #t_overview do
								local item = t_overview[i]
								local overview_color
								local slider_color = full_white

								if item.fx_id ~= last_fx then
									if child_open then
										reaper.ImGui_EndChild(ctx)
										child_open = false									
									end

									last_fx = item.fx_id

									-- compute exact height for this group
									local n = counts[item.fx_id]
									local n_mod = counts_line[item.fx_id]
																	
									local line_h = reaper.ImGui_GetFrameHeight(ctx) + 8
									local line_mod_h = reaper.ImGui_GetFrameHeight(ctx) + 1
									local height = 34 + (line_h * n) + (line_mod_h * n_mod)

									child_open = reaper.ImGui_BeginChild(ctx, item.fx_id, avail, height, reaper.ImGui_ChildFlags_Border(), reaper.ImGui_ChildFlags_AutoResizeY())
								end

							-- for _, item in ipairs(t_overview) do
								if child_open then

									reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 4, 2)

									-- Draw FX name if this is a new FX
									if i == 1 or item.fx_id ~= t_overview[i-1].fx_id then
										local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)
										local fx_name_bg = DarkerColor2(UI_color, 0.88)
										reaper.ImGui_DrawList_AddRectFilled(draw_list, screen_x - win_padding_x, screen_y - win_padding_y + 2, screen_x + avail - win_padding_x, screen_y - win_padding_y + 26, fx_name_bg, 7, reaper.ImGui_DrawFlags_RoundCornersTop())

										local fx_name_col = white

										local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, item.fx_name)
										local x, y = reaper.ImGui_GetCursorPos( ctx )
										reaper.ImGui_SetCursorPos(ctx, x, y+2)
										reaper.ImGui_InvisibleButton(ctx, "hover_area_fx", text_size_x, text_size_y)

										if reaper.ImGui_IsItemHovered(ctx) then
											fx_name_col = full_white											
										end

										-- Open FX
										if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
											if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
												reaper.TrackFX_Show(track, item.fx_id, 3) -- In floating window					
											else
												reaper.TrackFX_Show(track, item.fx_id, 1) -- In FXchain	
											end
										end					

										-- Draw the fx name
										reaper.ImGui_SameLine(ctx)
										reaper.ImGui_PushFont(ctx, fonts.medium_bold)
										reaper.ImGui_SetCursorPos(ctx, x, y)
										local width_for_fxName = reaper.ImGui_GetContentRegionAvail(ctx)
										local fx_name_clipped = ClipText(item.fx_name, width_for_fxName)
										reaper.ImGui_TextColored(ctx, fx_name_col, fx_name_clipped)
										if fx_name_clipped ~= item.fx_name then ToolTip(item.fx_name) end
										reaper.ImGui_PopFont(ctx)

										local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)
										-- reaper.ImGui_DrawList_AddLine(draw_list, screen_x - win_padding_x, screen_y - 1, screen_x + avail - win_padding_x, screen_y - 1, child_border_col, 1)
										reaper.ImGui_DrawList_AddLine(draw_list, screen_x - win_padding_x, screen_y - 1, screen_x + avail - win_padding_x, screen_y - 1, DarkerColor2(UI_color, 0.3), 1)
										reaper.ImGui_Dummy(ctx, 0, 6)

									end

									if track_color == UI_color then
										overview_color = DarkerColor2(full_white, 0.2)
										-- slider_color = full_white
									else
										overview_color = DarkerColor2(track_color, 0.1)
										-- slider_color = DarkerColor2(track_color, 0.1)
									end
									local text_size_x, text_size_y = reaper.ImGui_CalcTextSize(ctx, item.param_name)
									local x, y = reaper.ImGui_GetCursorPos( ctx )
									-- reaper.ImGui_SetCursorPos(ctx, x, y + 8)
									reaper.ImGui_InvisibleButton(ctx, "hover_area", text_size_x, text_size_y)

									if reaper.ImGui_IsItemHovered(ctx) then
										-- overview_color = full_white
										if track_color == UI_color then
											overview_color = full_white
										else
											overview_color = BrighterColor2(track_color, 0.3)
										end
									end

									-- Set as last touched parameter
									if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
										local current_val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
										reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, current_val) -- To set as last touched param
									end	

									-- Open native parameter modulation window
									if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then
										local current_val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
										reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, current_val) -- To set as last touched param										
										local _, visible = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".mod.visible")
										if visible == "1" then
											reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".mod.visible", 0)
										else
											for j=1, #t_overview do
												reaper.TrackFX_SetNamedConfigParm(track, t_overview[j].fx_id, "param." .. t_overview[j].param_id .. ".mod.visible", 0)
											end	
											reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".mod.visible", 1)
										end
										-- Command(41143) -- FX: Show parameter modulation/link for last touched FX parameter
									end											

									-- Delete modulation
									local unlink_confirmed								
									if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then																														
										local current_val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
										reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, current_val) -- To set as last touched param

										if user_os == "Win" then
											StartModalWorkaround("remove_mapping_mod_assign_list" .. i)
										else	
											local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove all the associated modulations?", "REMOVE MODULATIONS?", 4)
											if user_input_remove_mapping == 6 then -- YES
												unlink_confirmed = true
											end	
										end					
										-- UnlinkParam(track, item.fx_id, item.param_id)	
									end				

									if user_os == "Win" and modal_popup_id == "remove_mapping_mod_assign_list" .. i and modal_popup == true then
										local user_input_remove_mapping = reaper.ShowMessageBox("Are you sure you want to remove all the associated modulations?", "REMOVE MODULATIONS?", 4)
										if user_input_remove_mapping == 6 then -- YES
											unlink_confirmed = true
										end			
										ResetModalWorkaroundVariables()
									end										

									if unlink_confirmed == true then	
										UnlinkParam(track, item.fx_id, item.param_id)
										reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".mod.active", 0)
										reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".lfo.active", 0)
										reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".acs.active", 0)
										reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".learn.midi1", "")
										reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".learn.midi2", "")
									end

									-- Draw the param name with the determined color
									reaper.ImGui_SetCursorPos(ctx, x, y)	

									local width_for_paramName = width * 0.5 - win_padding_x * 2 - 4
									local param_name_clipped = ClipText(item.param_name, width_for_paramName)
									reaper.ImGui_TextColored(ctx, overview_color, param_name_clipped)
									if param_name_clipped ~= item.param_name then ToolTip(item.param_name) end									
									ToolTip("Alt-click: Delete all associated modulations")									

									-- Show baseline and mod amount sliders
									reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 0)

									local link_active = item.link_active
									local lfo_active = item.lfo_active
									local acs_active = item.acs_active
									local midi_learn = item.midi_learn

									local _, offset, offset_formatted																	
									local val, min, max = reaper.TrackFX_GetParamEx(track, item.fx_id, item.param_id)
									if link_active == 1 or lfo_active == 1 or acs_active == 1 then
										_, offset = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".mod.baseline")
									else
										offset = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
									end

									if max ~= 1 then -- If effect is a JSFX
										-- last_touched_param_value = (last_touched_param_value / max) - min -- Useful for JSFX with parameter value range > 1
										offset_formatted = offset
										offset_formatted = string.format("%.2f", offset_formatted)
										offset_formatted = offset_formatted:gsub("%%", "%%%%")						
									else
										rv, offset_formatted = reaper.TrackFX_FormatParamValueNormalized(track, item.fx_id, item.param_id, offset, "")												
										offset_formatted = ReplaceRareUnicode(offset_formatted)	
										offset_formatted = offset_formatted:gsub("%%", "%%%%")							
									end

									-- Special case of plugins not supporting the Cockos VST extension (hard-coded)
									if item.fx_name_raw:find("Valhalla DSP") then
										local baseline_rounded = string.format("%.2f", offset)
										offset_formatted = baseline_rounded
									end

									reaper.ImGui_SameLine(ctx)

									reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), DarkerColor2(overview_color, 0.2))
									reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), DarkerColor2(overview_color, 0.2))
									reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), slider_color)																									
									reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), DarkerColor2(overview_color, 0.8))
									reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0.1)																							

									-- reaper.ImGui_SetCursorPosX(ctx, avail * 0.5 - 4)
									reaper.ImGui_SetCursorPos(ctx, avail * 0.5 - 4, y - 2)
									reaper.ImGui_SetNextItemWidth(ctx, avail * 0.5 - win_padding_x - 4)
									local rv_offset, offset = reaper.ImGui_SliderDouble(ctx, "##offset" .. item.param_id, offset, min, max, offset_formatted)
									if rv_offset then

										overview_baseline = true -- show mod range on baseline slider while adjusting offset slider										

										if link_active == 1 or lfo_active == 1 or acs_active == 1 then
											-- active as last-touched FX param
											local val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
											reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, val)

											reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".mod.baseline", offset)
										else
											reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, offset)
										end										
									end																												

									reaper.ImGui_PopStyleVar(ctx, 1)
									reaper.ImGui_PopStyleColor(ctx, 4)	

									-- Draw MOD or MACRO slider
									local rv_amount
									
									if link_active == 1 then

										local _, link_source_fx = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".plink.effect")
										local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".plink.param")																													
										link_source_fx = tonumber(link_source_fx)
										link_source_param = tonumber(link_source_param)

										local mod_or_macro
										local flashmob_inst
										for j=1, #t_flashmob_id do
											if link_source_fx == t_flashmob_id[j] then												
												if link_source_param < 7 then
													mod_or_macro = "Macro"												
												else
													mod_or_macro = "Mod"
												end
												flashmob_inst = j
												break	
											end
										end			
										if not mod_or_macro then mod_or_macro = "External" end

										local x, y = reaper.ImGui_GetCursorPos(ctx)
										reaper.ImGui_SetCursorPosY(ctx, y + 1)

										reaper.ImGui_BeginGroup(ctx)
										reaper.ImGui_TextColored(ctx, UI_color, mod_or_macro)

										-- Display mod number in a circle
										reaper.ImGui_SameLine(ctx)	
										local center_x, center_y = reaper.ImGui_GetCursorScreenPos(ctx)

										-- local slider_color = UI_color
										if mod_or_macro ~= "External" then
											if link_source_param > 7 then
												reaper.ImGui_DrawList_AddCircle(draw_list, center_x + 4, center_y + 6, 8, t_color_palette[link_source_param - 7], num_segmentsIn, thicknessIn)
												-- slider_color = t_color_palette[link_source_param - 7]
											else
												-- reaper.ImGui_DrawList_AddCircle(draw_list, center_x + 4, center_y + 6, 8, UI_color, num_segmentsIn, thicknessIn)
												reaper.ImGui_DrawList_AddRect(draw_list, center_x - 4, center_y - 2, center_x + 12, center_y + 14, t_color_palette[flashmob_inst], roundingIn, flagsIn, thicknessIn)												
												-- slider_color = t_color_palette[flashmob_inst]
											end

											if link_source_param > 7 then
												reaper.ImGui_TextColored(ctx, t_color_palette[link_source_param - 7], link_source_param - 7)
											else
												reaper.ImGui_TextColored(ctx, t_color_palette[flashmob_inst], link_source_param + 1)
											end		
										end	
										reaper.ImGui_EndGroup(ctx)

										if mod_or_macro == "Mod" and reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
											local index = 1
											local _, link_source_param = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".plink.param")
											link_source_param = tonumber(link_source_param)
											if link_source_param > 7 and link_source_param <= 9 then index = 1 end
											if link_source_param > 9 and link_source_param <= 11 then index = 3 end											
											if link_source_param > 11 and link_source_param <= 13 then index = 5 end																						
											OpenSnapheap(track, mod_container_id, index)
										end											

										reaper.ImGui_SameLine(ctx)	
											
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), DarkerColor2(slider_color, 0.4))
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), DarkerColor2(slider_color, 0.4))
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), DarkerColor2(slider_color, 0.4))																								

										reaper.ImGui_SetCursorPos(ctx, avail * 0.5 - 4, y - 1)
										local _, amount = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".plink.scale")
										local amount_formatted = string.format('%.1f %%%%', amount * 100)

										reaper.ImGui_SetNextItemWidth(ctx, avail * 0.5 - win_padding_x - 4)
										rv_amount, amount = reaper.ImGui_SliderDouble(ctx, "##amount" .. item.param_id, amount, -1, 1, amount_formatted)
										if rv_amount then

											show_mod_value = true
											overview_scale = true -- show mod range on baseline slider while adjusting mod amount slider

											-- active as last-touched FX param
											local val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
											reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, val)

											reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".plink.scale", amount)
										end										
										reaper.ImGui_PopStyleColor(ctx, 3)	
									end	

									-- Draw LFO slider
									local rv_lfo_strength									

									if lfo_active == 1 then

										local x, y = reaper.ImGui_GetCursorPos(ctx)
										reaper.ImGui_SetCursorPosY(ctx, y + 1)

										reaper.ImGui_TextColored(ctx, UI_color, "Lfo")
										reaper.ImGui_SameLine(ctx)

										local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)										
										SineWave(draw_list, screen_x, screen_y, 16, 14, UI_color, 2)

										reaper.ImGui_SameLine(ctx)	
										
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), DarkerColor2(slider_color, 0.4))
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), DarkerColor2(slider_color, 0.4))
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), DarkerColor2(slider_color, 0.4))																									

										reaper.ImGui_SetCursorPos(ctx, avail * 0.5 - 4, y - 1)
										local _, lfo_strength = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".lfo.strength")
										-- lfo_strength = tonumber(lfo_strength)
										local lfo_strength_formatted = string.format('%.1f %%%%', lfo_strength * 100)

										reaper.ImGui_SetNextItemWidth(ctx, avail * 0.5 - win_padding_x - 4)
										rv_lfo_strength, lfo_strength = reaper.ImGui_SliderDouble(ctx, "##lfo_strength" .. item.param_id, lfo_strength, 0, 1, lfo_strength_formatted)
										if rv_lfo_strength then

											lfo_strength_adjust = 1

											-- active as last-touched FX param
											local val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
											reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, val)

											reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".lfo.strength", lfo_strength)											
										end	

										-- Show mod range on LAST FX PARAM baseline slider
										if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_RectOnly()) then
											hover_lfo = 1
										end																											

										reaper.ImGui_PopStyleColor(ctx, 3)	
									end	

									-- Draw ACS slider
									local rv_acs_strength									

									if acs_active == 1 then

										local x, y = reaper.ImGui_GetCursorPos(ctx)
										reaper.ImGui_SetCursorPosY(ctx, y + 1)

										reaper.ImGui_TextColored(ctx, UI_color, "Acs")
										reaper.ImGui_SameLine(ctx)

										local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)										
										ADEnvelope(draw_list, screen_x, screen_y, 16, 14, UI_color, 2)

										reaper.ImGui_SameLine(ctx)	
										
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), DarkerColor2(slider_color, 0.4))
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), DarkerColor2(slider_color, 0.4))
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), DarkerColor2(slider_color, 0.4))																									

										reaper.ImGui_SetCursorPos(ctx, avail * 0.5 - 4, y - 1)
										local _, acs_strength = reaper.TrackFX_GetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".acs.strength")
										-- acs_strength = tonumber(acs_strength)
										local acs_strength_formatted = string.format('%.1f %%%%', acs_strength * 100)

										reaper.ImGui_SetNextItemWidth(ctx, avail * 0.5 - win_padding_x - 4)
										rv_acs_strength, acs_strength = reaper.ImGui_SliderDouble(ctx, "##acs_strength" .. item.param_id, acs_strength, 0, 1, acs_strength_formatted)
										if rv_acs_strength then

											acs_strength_adjust = 1

											-- active as last-touched FX param
											local val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
											reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, val)

											reaper.TrackFX_SetNamedConfigParm(track, item.fx_id, "param." .. item.param_id .. ".acs.strength", acs_strength)
										end	

										if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_RectOnly()) then
											hover_acs = 1
										end										

										reaper.ImGui_PopStyleColor(ctx, 3)	
									end	

									if midi_learn and midi_learn ~= 0 then

										local x, y = reaper.ImGui_GetCursorPos(ctx)
										reaper.ImGui_SetCursorPosY(ctx, y + 1)

										reaper.ImGui_TextColored(ctx, UI_color, "Midi")
										reaper.ImGui_SameLine(ctx)

										local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)										
										Midi(draw_list, screen_x - 3, screen_y, 16, 14, UI_color, 2)

										reaper.ImGui_SameLine(ctx)	

										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), white)
										reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), DarkerColor2(UI_color, 0.4))
										reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)																									

										reaper.ImGui_SetCursorPos(ctx, avail * 0.5 - 4, y - 1)

										if reaper.ImGui_Button(ctx, "Learn", avail * 0.5 - win_padding_x - 4, 16) then

											-- active as last-touched FX param
											local val = reaper.TrackFX_GetParam(track, item.fx_id, item.param_id)
											reaper.TrackFX_SetParam(track, item.fx_id, item.param_id, val)

											if user_os == "Win" then
												StartModalWorkaround("nativeTab_midiLearn" .. i)
											else
												Command(41144) -- FX: Set MIDI learn for last touched FX parameter
												GetPMData(track, item.fx_id, item.param_id)
											end
											-- Command(41144) -- FX: Set MIDI learn for last touched FX parameter
										end	

										if user_os == "Win" and modal_popup_id == "nativeTab_midiLearn" .. i and modal_popup == true then
											Command(41144) -- FX: Set MIDI learn for last touched FX parameter			
											GetPMData(track, item.fx_id, item.param_id)	
											ResetModalWorkaroundVariables()
										end										

										reaper.ImGui_PopStyleVar(ctx, 1)
										reaper.ImGui_PopStyleColor(ctx, 2)	
									end																			

									-- Update data
									if rv_offset or rv_amount or rv_lfo_strength or rv_acs_strength then
										GetLastTouchedFXParam(track)
										GetPMData(track, item.fx_id, item.param_id)
									end					

									reaper.ImGui_PopStyleVar(ctx, 2)

									if i < #t_overview and item.fx_id == t_overview[i+1].fx_id then
										reaper.ImGui_Separator(ctx)										
										reaper.ImGui_Dummy(ctx, 0, 0)																
									end			
								end													
							end	

							if child_open then								
								reaper.ImGui_EndChild(ctx)
							end

							if #t_overview == 0 then
								reaper.ImGui_PushTextWrapPos(ctx, width - win_padding_x - 8)
								reaper.ImGui_Text(ctx, "This track does not have any modulation yet")
								reaper.ImGui_PopTextWrapPos(ctx)
							end

							reaper.ImGui_PopStyleColor(ctx, 1)
							reaper.ImGui_PopStyleVar(ctx, 2) -- FX Child
							reaper.ImGui_EndChild(ctx)

						else				

							reaper.ImGui_BeginTabBar(ctx, "MyTabs")

							local screen_x, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)	

							reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(), 2, 4) -- Reduce space between tab items

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


							-- Draw a line below the tab item to indicate that mod is active on the last-touched FX param
							if rv_flashmob == true and t_pm_data.link_source_fx == mod_container_id and t_pm_data.link_source_param > 7 then
								local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
								local line_color = track_color
								if line_color == UI_color then line_color = full_white end
								reaper.ImGui_DrawList_AddLine(draw_list, screen_x, screen_y - 5, screen_x + width / 3 - win_padding_x + 1, screen_y - 5, line_color, 2)
							end

							reaper.ImGui_SetNextItemWidth(ctx, width / 3 - win_padding_x + 2)
							local tab_selected_mod = reaper.ImGui_BeginTabItem(ctx, "Mod", false, flag1)
							if tab_selected_mod then
								opened_tab = 1

								if rv_flashmob == true then	
									if not flashmob_is_invalid then
										reaper.ImGui_BeginChild(ctx, "mod_child", size_wIn, size_hIn, borderIn, reaper.ImGui_ChildFlags_AutoResizeY()) -- To restrict the scrollbar to the mod tab content

										if (tab_selected_mod and not previous_tab_selected_mod) or slower_defer_update then
											CheckIfModIsUsed(track, mod_container_id)
										end

										for i=1, 6 do
											ModChild(track, mod_container_id, i, t_last_param.fx, t_last_param.param, track_sel_changed, param_is_linked_to_anything)						
										end
										reaper.ImGui_EndChild(ctx)

										-- If any MOD popup is open, set macro_mod_enable to 1 to be able to click and set modulated MACRO as last-touched FX param
										local modPopup_open
										for i=1, 6 do
											if _G["modPopup" .. i] == 1 then
												modPopup_open = true
												break
											end
										end
										if modPopup_open then
											if not previous_macro_mod_enable then
												previous_macro_mod_enable = macro_mod_enable
												macro_mod_enable = 1
											end
										else				
											if previous_macro_mod_enable then			
												macro_mod_enable = previous_macro_mod_enable
												previous_macro_mod_enable = nil
											end
										end

									else
										reaper.ImGui_PushTextWrapPos(ctx, width)
										local invalid_flashmob_text = "Khs SnapHeap plugin is probably missing\nPlease read the manual for more info"
										-- invalid_flashmob_text = WrapText(invalid_flashmob_text, width)								
										reaper.ImGui_Text(ctx, invalid_flashmob_text)
										reaper.ImGui_PopTextWrapPos(ctx)
									end

									previous_tab_selected_mod = tab_selected_mod
								else
									local height = 154
									if t_pm_data.lfo_active == 1 then
										height = height + 180
									end
									if t_pm_data.acs_active == 1 then
										height = height + 180
									end															
									reaper.ImGui_Dummy(ctx, 0, 0)
									local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
									local button_width = width * 0.75	
									local button_height = 54
									local center_x = x + (width * 0.5) - (button_width * 0.5) - win_padding_x
									local center_y = y + (height * 0.5) - (button_height * 0.5) - win_padding_y * 2 - 10
									reaper.ImGui_PushFont(ctx, fonts.medium_bold)
									rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, DarkerColor2(UI_color, 0.25), DarkerColor2(UI_color, 0.1), 1)
									reaper.ImGui_PopFont(ctx)
									ToolTip("Click to enable FLASHMOB modulations on this track")
									if rv_addContainer then
										if reaper.file_exists(script_path .. "FXChains/" .. default_preset .. ".RfxChain") then
											AddFlashmobInstance(track, 1)
											reload_settings = true											
										else
											if user_os == "Win" then
												StartModalWorkaround("error_missing_fxchain" .. str_index)
											else	
												reaper.ShowMessageBox(script_path .. "FXChains/" .. default_preset .. ".RfxChain file is missing.\n\nPlease, choose another default preset in the script settings or reinstall the script.", "ERROR", 0)
											end								
										end
									end	
								end

								reaper.ImGui_EndTabItem(ctx)
							end

							-- Draw a line below the tab item to indicate that macro is active on the last-touched FX param
							if rv_flashmob == true and t_pm_data.link_source_fx == mod_container_id and t_pm_data.link_source_param <= 7 then							
								local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
								local line_color = track_color
								if line_color == UI_color then line_color = full_white end							
								reaper.ImGui_DrawList_AddLine(draw_list, screen_x + width / 3 - win_padding_x + 3, screen_y - 5, screen_x + (width / 3 * 2) - win_padding_x - 4, screen_y - 5, line_color, 2)
							end						

							reaper.ImGui_SetNextItemWidth(ctx, width / 3 - win_padding_x + 1)
							local tab_selected_macro = reaper.ImGui_BeginTabItem(ctx, "Macro", false, flag2)
							if tab_selected_macro then
								opened_tab = 2
								if rv_flashmob == true then	

									reaper.ImGui_BeginChild(ctx, "macro_child", size_wIn, size_hIn, borderIn, reaper.ImGui_ChildFlags_AutoResizeY()) -- To restrict the scrollbar to the mod tab content

									if (tab_selected_macro and not previous_tab_selected_macro) or slower_defer_update then
										CheckIfMacroIsUsed(track, mod_container_id)
									end

									for i=1, 8 do
										Macro(track, mod_container_id, i, t_last_param.fx, t_last_param.param, track_sel_changed, param_is_linked_to_anything)
									end	
									reaper.ImGui_EndChild(ctx)	

									-- If any MACRO popup is open, set macro_mod_enable to 1 to be able to click and set modulated MACRO as last-touched FX param
									local macroPopup_open
									for i=1, 8 do
										if _G["macroPopup" .. i] == 1 then
											macroPopup_open = true
											break
										end
									end
									if macroPopup_open then
										if not previous_macro_mod_enable then
											previous_macro_mod_enable = macro_mod_enable
											macro_mod_enable = 1
										end
									else				
										if previous_macro_mod_enable then			
											macro_mod_enable = previous_macro_mod_enable
											previous_macro_mod_enable = nil
										end
									end										

									previous_tab_selected_macro = tab_selected_macro
								else
									reaper.ImGui_Dummy(ctx, 0, 0)
									local height = 154
									if t_pm_data.lfo_active == 1 then
										height = height + 180
									end
									if t_pm_data.acs_active == 1 then
										height = height + 180
									end								
									local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
									local button_width = width * 0.75	
									local button_height = 54
									local center_x = x + (width * 0.5) - (button_width * 0.5) - win_padding_x
									-- local center_y = y + (height * 0.5) - (button_height * 0.5) - win_padding_y * 2 - 10
									local center_y = y + (height * 0.5) - (button_height * 0.5) - win_padding_y * 2 - 10
									reaper.ImGui_PushFont(ctx, fonts.medium_bold)
									rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, DarkerColor2(UI_color, 0.25), DarkerColor2(UI_color, 0.1), 1)
									reaper.ImGui_PopFont(ctx)
									ToolTip("Click to enable FLASHMOB macros on this track")
									if rv_addContainer then
										if reaper.file_exists(script_path .. "FXChains/" .. default_preset .. ".RfxChain") then
											AddFlashmobInstance(track, 1)
											reload_settings = true											
										else
											if user_os == "Win" then
												StartModalWorkaround("error_missing_fxchain" .. str_index)
											else	
												reaper.ShowMessageBox(script_path .. "FXChains/" .. default_preset .. ".RfxChain file is missing.\n\nPlease, choose another default preset in the script settings or reinstall the script.", "ERROR", 0)
											end								
										end
									end	
								end
								reaper.ImGui_EndTabItem(ctx)
							end	

							-- Draw a line below the tab item to indicate that native is active on the last-touched FX param
							if t_pm_data.lfo_active == 1 or t_pm_data.acs_active == 1 or (t_pm_data.midi_learn and t_pm_data.midi_learn ~= 0) then							
								local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
								local line_color = track_color
								if line_color == UI_color then line_color = full_white end							
								reaper.ImGui_DrawList_AddLine(draw_list, screen_x + (width / 3 * 2) - win_padding_x - 2, screen_y - 5, screen_x + width - win_padding_x - 8, screen_y - 5, line_color, 2)
							end												
			
							reaper.ImGui_SetNextItemWidth(ctx, width / 3 - win_padding_x + 1)
							local tab_selected_native = reaper.ImGui_BeginTabItem(ctx, "Native", false, flag3)					
							if t_last_param.param then

								-- Get LFO data for first frame of the tab or if project state change
								if (tab_selected_native and not previous_tab_selected_native) or (tab_selected_native and slower_defer_update) then
									GetNativeLFOData(track, t_last_param.fx, t_last_param.param)
									GetNativeACSData(track, t_last_param.fx, t_last_param.param)
								end
								-- Draw LFO GUI
								if tab_selected_native then
									DrawMIDILearn(track, t_last_param.fx, t_last_param.param)
									DrawNativeLFO(track, t_last_param.fx, t_last_param.param)
									DrawNativeACS(track, t_last_param.fx, t_last_param.param)													
								end
								previous_tab_selected_native = tab_selected_native											
							else
								if tab_selected_native then
									reaper.ImGui_PushTextWrapPos(ctx, 0)
									reaper.ImGui_Text(ctx, "No last-touched FX parameter detected")
									reaper.ImGui_PopTextWrapPos(ctx)
								end
							end								

							if tab_selected_native then
								opened_tab = 3
								reaper.ImGui_EndTabItem(ctx)
							end				

							-- Save opened tab when tab selection change
							if opened_tab ~= last_opened_tab then
								reaper.SetProjExtState(0, "vf_flashmob", "last_tab", opened_tab)
								last_opened_tab = opened_tab
							end

							reaper.ImGui_PopStyleVar(ctx, 1) -- Pop ItemInnerSpacing

							reaper.ImGui_EndTabBar(ctx)
						end
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
	

			-- else
			-- 	reaper.ImGui_Dummy(ctx, 0, 0)
			-- 	local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
			-- 	local button_width = width * 0.75	
			-- 	local button_height = height * 0.35		
			-- 	local center_x = x + (width * 0.5) - (button_width * 0.5) - win_padding_x
			-- 	local center_y = y + (height * 0.5) - (button_height * 0.5) - win_padding_y * 2 - 10
			-- 	-- reaper.ImGui_SetCursorPos(ctx, center_x, center_y)
			-- 	reaper.ImGui_PushFont(ctx, fonts.medium_bold)
			-- 	-- rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, white, track_color, 1)
			-- 	-- rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, DarkerColor2(track_color, 0.4), DarkerColor2(track_color, 0.2), 1)
			-- 	rv_addContainer = GradientButton(ctx, "Enable Flashmob", center_x, center_y, button_width, button_height, DarkerColor2(UI_color, 0.25), DarkerColor2(UI_color, 0.1), 1)
			-- 	-- rv_addContainer = reaper.ImGui_Button(ctx, "Enable Flashmob", button_width, button_height)
			-- 	reaper.ImGui_PopFont(ctx)
			-- 	ToolTip("Click to enable FLASHMOB modulations & macros on this track")
			-- 	if rv_addContainer then
			-- 		-- reaper.TrackFX_AddByName(track, "../Scripts/VF_ReaScripts Beta/Flashmob/Flashmob.RfxChain", false, 1000)	-- last argument adds an instance if one is not found at the first FX chain index				
			-- 		if reaper.file_exists(script_path .. "FXChains/" .. default_preset .. ".RfxChain") then
			-- 			AddFlashmobInstance(track, 1)
			-- 			reload_settings = true						
			-- 			-- local openFloating_setting = reaper.SNM_GetIntConfigVar("fxfloat_focus", -666) -- Save the original user setting to open or not floating window when adding new FX
			-- 			-- reaper.SNM_SetIntConfigVar("fxfloat_focus", openFloating_setting&(~4)) -- Temporarly disable the user setting
			-- 			-- reaper.TrackFX_AddByName(track, "../Scripts/VF_ReaScripts Beta/Flashmob/FXChains/" .. default_preset  .. ".RfxChain", false, 1024)	-- last argument adds an instance if one is not found at the first FX chain index				
			-- 			-- reaper.TrackFX_CopyToTrack(track, reaper.TrackFX_GetCount(track)-1, track, 0, 1) -- Move Flashmob to the first FX chain slot
			-- 			-- reaper.SNM_SetIntConfigVar("fxfloat_focus", openFloating_setting) -- Restore user setting						
			-- 		else
			-- 			if user_os == "Win" then
			-- 				StartModalWorkaround("error_missing_fxchain" .. str_index)
			-- 			else	
			-- 				reaper.ShowMessageBox(script_path .. "FXChains/" .. default_preset .. ".RfxChain file is missing.\n\nPlease, choose another default preset in the script settings or reinstall the script.", "ERROR", 0)
			-- 			end								
			-- 		end
			-- 	end	
			-- end
		end

	else
		reaper.ImGui_Text(ctx, "No selected track")
	end


	-- Reaper native modal error messages (Windows workaround)
	if user_os == "Win" and modal_popup_id == "error_missing_fxchain" and modal_popup == true then
		reaper.ShowMessageBox(script_path .. "FXChains/" .. default_preset .. ".RfxChain file is missing.\n\nPlease, choose another default preset in the script settings or reinstall the script.", "ERROR", 0)
		ResetModalWorkaroundVariables()
	end	

	if user_os == "Win" and modal_popup_id == "map_no_param" and modal_popup == true then
		reaper.ShowMessageBox("\nYou must adjust an FX parameter before mapping to this modulator", "MAPPING FAILED", 0)		
		ResetModalWorkaroundVariables()
	end				


	local popup_open = reaper.ImGui_IsPopupOpen(ctx, "", reaper.ImGui_PopupFlags_AnyPopupId() | reaper.ImGui_PopupFlags_AnyPopupLevel()) -- Check if any popup is opened	
	-- if (reaper.ImGui_IsMouseReleased(ctx, reaper.ImGui_MouseButton_Left()) or reaper.ImGui_IsMouseReleased(ctx, reaper.ImGui_MouseButton_Right())) and popup_open == false and combo_open == false then
	if (reaper.ImGui_IsMouseReleased(ctx, reaper.ImGui_MouseButton_Left()) or reaper.ImGui_IsMouseReleased(ctx, reaper.ImGui_MouseButton_Right())) and popup_open == false then
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
	-- local start = reaper.time_precise()

	reaper.ImGui_PushFont(ctx, fonts.medium)
	reaper.ImGui_SetNextWindowSize(ctx, 480, 320, reaper.ImGui_Cond_FirstUseEver())
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 10, val2In)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(), 3)
	reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), 11)	

	local main_height = 82
	if help_page == 1 or settings_page == 1 then
		main_height = 704
	else 
		if custom_headers["Header_Source"] then 
			if full == 1 then 
				main_height = 594 
			else
				if rv_flashmob == true then
					main_height = main_height + 512
					if instance_nb > 1 then
						main_height = main_height + 24
					end
				else
					main_height = 232
					if t_pm_data.lfo_active == 1 then
						main_height = main_height + 180
					end
					if t_pm_data.acs_active == 1 then
						main_height = main_height + 180
					end					
				end
			end
		end
		if custom_headers["Header_Param"] then 
			if rv_flashmob == true then
				main_height = main_height + 110
			else
				main_height = main_height + 71
			end
		end
	end

	reaper.ImGui_SetNextWindowSizeConstraints(ctx, 160, main_height, 600, main_height)

	SetTheme()

	-- local main_window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_TopMost() | reaper.ImGui_WindowFlags_NoFocusOnAppearing() | reaper.ImGui_WindowFlags_NoTitleBar()
	local main_window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoFocusOnAppearing() | reaper.ImGui_WindowFlags_NoTitleBar()
	if not reaper.ImGui_IsWindowDocked(ctx) then
		if help_page == 0 then
			main_window_flags = main_window_flags | reaper.ImGui_WindowFlags_NoScrollbar()
		end
	end

	-- reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 8)

	-- Workaround to fix issue with Reaper native modal windows opening behind the ImGui window (Thanks CFillion)
	-- When script want to open a native modal:
		-- 1. clear WindowFlags_TopMost and wait a frame
		-- 2. open the modal dialog (the script is suspended while it's open since it's waiting on the modal to return)
		-- 3. set WindowFlags_TopMost on the next frame	
	if user_os == "Win" then
		if not modal_popup_prepare and not wait1Frame then
			main_window_flags = main_window_flags | reaper.ImGui_WindowFlags_TopMost()
		end

		if wait1Frame then modal_popup = true end

		if modal_popup_prepare then
			wait1Frame = true
		end	
	else
		main_window_flags = main_window_flags | reaper.ImGui_WindowFlags_TopMost()
	end

	-- visible, open = reaper.ImGui_Begin(ctx, 'FLASHMOB', true, reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_NoDocking())	
	visible, open = reaper.ImGui_Begin(ctx, 'FLASHMOB', true, main_window_flags)
	if visible then
		Frame()
		reaper.ImGui_End(ctx)	
	end

	-- reaper.ImGui_PopStyleVar(ctx, 1)

	reaper.ImGui_PopStyleColor(ctx, 13) -- Theme	
	reaper.ImGui_PopStyleVar(ctx, 3)
	reaper.ImGui_PopFont(ctx)	

	-- local elapsed = reaper.time_precise() - start
	-- Print("Script executed in ".. elapsed .." seconds")	

	if open then
		reaper.defer(Loop)
	end
end

-- local start = reaper.time_precise()

-- local profiler = dofile(reaper.GetResourcePath() ..
--   '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
-- reaper.defer = profiler.defer
-- profiler.attachToWorld() -- after all functions have been defined
-- profiler.detachFrom('debug.getinfo')
-- profiler.run()

if Init() == true then
	reaper.defer(Loop)
end

-- local elapsed = reaper.time_precise() - start
-- Print("Script executed in ".. elapsed .." seconds")


