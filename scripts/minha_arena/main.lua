-- Arena personalizada com fireball e colisão
local fireballs = {}
local current_tick = 0

-- Configurações da fireball
local FIREBALL_SPEED = 20.0
local FIREBALL_LIFETIME = 120  -- ticks (~4 segundos)
local FIREBALL_DAMAGE = 10
local FIREBALL_RADIUS = 0.5
local FIREBALL_SPAWN_OFFSET = 1.0
local HIT_RADIUS = 3.0

-- Configurações de movimento
local PLAYER_SPEED = 5.0

-- Função para verificar se uma entidade é um jogador
local function is_player(entity_id)
    local kind = Loci.get_entity_property(entity_id, "kind")
    return kind == "player"
end

-- Função para aplicar dano
local function apply_damage(entity_id, damage)
    local current_hp = Loci.get_entity_property(entity_id, "hp") or 100
    local new_hp = current_hp - damage
    Loci.set_entity_property(entity_id, "hp", new_hp)
    
    if new_hp <= 0 then
        Loci.Commands.destroy_entity(entity_id)
    end
end

-- Callback quando um jogador entra na arena
function on_player_join(entity_id)
    Loci.Commands.set_property(entity_id, "hp", "100")
    Loci.Commands.set_property(entity_id, "kind", "player")
    Loci.Commands.set_property(entity_id, "team", "1")
end

-- Callback quando o jogador tenta se mover
function on_move_intent(entity_id, dir_x, dir_y)
    Loci.Commands.set_velocity(entity_id, {x = dir_x * PLAYER_SPEED, y = dir_y * PLAYER_SPEED})
    return true
end

-- Callback quando um jogador usa uma habilidade
function on_action(entity_id, ability_id, aim_x, aim_y)
    if ability_id == 1 then
        local pos = Loci.get_entity_position(entity_id)
        if pos then
            local px, py = pos:x_float(), pos:y_float()
            
            -- Calcular direção baseada na mira
            local len = math.sqrt(aim_x * aim_x + aim_y * aim_y)
            
            if len > 0 then
                aim_x = aim_x / len
                aim_y = aim_y / len
            else
                aim_x = 1
                aim_y = 0
            end
            
            -- Spawn da fireball com offset
            local spawn_x = px + aim_x * FIREBALL_SPAWN_OFFSET
            local spawn_y = py + aim_y * FIREBALL_SPAWN_OFFSET
            
            local fireball_id = Loci.Commands.spawn_entity({
                position = { x = spawn_x, y = spawn_y },
                blueprint = "fireball",
                entity_type = "Prop",
                move_speed = FIREBALL_SPEED,
                radius = FIREBALL_RADIUS,
                properties = {
                    owner = tostring(entity_id),
                    kind = "fireball"
                }
            })
            
            if fireball_id then
                Loci.Commands.set_velocity(fireball_id, {x = aim_x * FIREBALL_SPEED, y = aim_y * FIREBALL_SPEED})
                
                fireballs[#fireballs + 1] = {
                    id = fireball_id,
                    owner = entity_id,
                    expires_at = current_tick + FIREBALL_LIFETIME
                }
            end
        end
    end
    
    return true
end

-- Callback quando dois jogadores colidem
function on_collision(entity_a_id, entity_b_id)
    local kind_a = Loci.get_entity_property(entity_a_id, "kind")
    local kind_b = Loci.get_entity_property(entity_b_id, "kind")
    
    -- Se uma das entidades é fireball, destrói
    if kind_a == "fireball" then
        Loci.Commands.destroy_entity(entity_a_id)
    end
    if kind_b == "fireball" then
        Loci.Commands.destroy_entity(entity_b_id)
    end
end

-- Tick loop
function on_tick(tick)
    current_tick = tick
    if #fireballs == 0 then
        return
    end

    local alive = {}
    for _, fb in ipairs(fireballs) do
        local keep = true
        local pos = Loci.get_entity_position(fb.id)

        if not pos or tick >= fb.expires_at then
            Loci.Commands.destroy_entity(fb.id)
            keep = false
        else
            local near = Loci.get_entities_in_radius(pos, HIT_RADIUS)
            for _, id in ipairs(near) do
                if keep and id ~= fb.id and id ~= fb.owner then
                    local entity_kind = Loci.get_entity_property(id, "kind")
                    if is_player(id) or entity_kind == "fireball" then
                        if is_player(id) then
                            apply_damage(id, FIREBALL_DAMAGE)
                        end
                        Loci.Commands.destroy_entity(fb.id)
                        keep = false
                    end
                end
            end
        end

        if keep then
            alive[#alive + 1] = fb
        end
    end
    fireballs = alive
end
