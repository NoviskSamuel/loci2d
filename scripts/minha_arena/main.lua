-- Arena personalizada com fireball e colisão
local fireballs = {}
local current_tick = 0

-- Configurações da fireball
local FIREBALL_SPEED = 2.0  -- Igual à velocidade do jogador para gameplay mais controlável
local FIREBALL_LIFETIME = 120  -- ticks (~4 segundos)
local FIREBALL_DAMAGE = 10
local FIREBALL_RADIUS = 2
local FIREBALL_SPAWN_OFFSET = 0.0  -- Spawna dentro do jogador para garantir que pegue de perto
local HIT_RADIUS = 5.0  -- Aumentado para 5.0 para detectar colisão melhor em toda a hitbox

-- Configurações de movimento
local PLAYER_SPEED = 5.0

-- Configurações de colisão
local SOLID_WALL = 1
local PLAYER = 2
local PROJECTILE = 8

-- Rastrear última direção de movimento para quando jogador estiver parado
local last_move_directions = {}

-- Função para verificar se uma entidade é um jogador
local function is_player(entity_id)
    local kind = Loci.get_entity_property(entity_id, "kind")
    return kind == "player"
end

-- Função para aplicar dano
local function apply_damage(entity_id, damage)
    local current_hp = Loci.get_entity_property(entity_id, "hp") or 100
    local new_hp = current_hp - damage
    Loci.Commands.set_property(entity_id, "hp", tostring(new_hp))
    
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

-- Inicialização da arena - criar obstáculos estáticos
function on_init()
    -- Define o mapa como 100x100 (de -50 a 50)
    Loci.Commands.set_map_bounds({x = -50, y = -50}, {x = 50, y = 50})
    
    -- Paredes do mapa 100x100 (de -50 a 50, com espessura 2)
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -52, y = -50 }, max = { x = -50, y = 50 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })  -- Parede esquerda
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = 50, y = -50 }, max = { x = 52, y = 50 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })  -- Parede direita
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -50, y = -52 }, max = { x = 50, y = -50 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })  -- Parede superior
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -50, y = 50 }, max = { x = 50, y = 52 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })  -- Parede inferior
    
    -- Obstáculo circular central
    Loci.Commands.add_static_obstacle({
        shape = { type = "circle", center = { x = 0, y = 0 }, radius = 5.0 },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    -- Obstáculos nos cantos
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -30, y = -30 }, max = { x = -25, y = -25 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = 25, y = -30 }, max = { x = 30, y = -25 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -30, y = 25 }, max = { x = -25, y = 30 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = 25, y = 25 }, max = { x = 30, y = 30 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    -- Obstáculos no meio
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -10, y = -20 }, max = { x = -5, y = -15 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = 5, y = -20 }, max = { x = 10, y = -15 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = -10, y = 15 }, max = { x = -5, y = 20 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
    
    Loci.Commands.add_static_obstacle({
        shape = { type = "aabb", min = { x = 5, y = 15 }, max = { x = 10, y = 20 } },
        layer = SOLID_WALL,
        mask = PLAYER | PROJECTILE,
        is_solid = true
    })
end

-- Callback quando o jogador tenta se mover
function on_move_intent(entity_id, dir_x, dir_y)
    -- Rastreia a última direção de movimento
    if dir_x ~= 0 or dir_y ~= 0 then
        last_move_directions[entity_id] = {x = dir_x, y = dir_y}
        
        -- Usa set_navigation_target com alvo distante para movimento contínuo
        local pos = Loci.get_entity_position(entity_id)
        if pos then
            local px, py = pos:x_float(), pos:y_float()
            -- Alvo muito distante (100 unidades) para movimento contínuo
            local target_x = px + dir_x * 100
            local target_y = py + dir_y * 100
            Loci.Commands.set_navigation_target(entity_id, {x = target_x, y = target_y})
        end
    else
        -- Se parado, para a navegação
        Loci.Commands.set_velocity(entity_id, {x = 0, y = 0})
    end
    
    return true
end

-- Callback quando um jogador usa uma habilidade
function on_action(entity_id, ability_id, aim_x, aim_y)
    if ability_id == 1 then
        local pos = Loci.get_entity_position(entity_id)
        if pos then
            local px, py = pos:x_float(), pos:y_float()
            
            -- Pegar velocidade atual do jogador para determinar direção
            local vel = Loci.get_entity_velocity(entity_id)
            local dir_x, dir_y = 1, 0  -- Direção padrão para direita
            
            if vel then
                local vx, vy = vel:x_float(), vel:y_float()
                local len = math.sqrt(vx * vx + vy * vy)
                
                if len > 0.1 then  -- Se o jogador está se movendo
                    dir_x = vx / len
                    dir_y = vy / len
                else
                    -- Se parado, usa última direção de movimento
                    local last_dir = last_move_directions[entity_id]
                    if last_dir then
                        dir_x = last_dir.x
                        dir_y = last_dir.y
                    end
                end
            end
            
            -- Spawn da fireball com offset na direção do movimento
            local spawn_x = px + dir_x * FIREBALL_SPAWN_OFFSET
            local spawn_y = py + dir_y * FIREBALL_SPAWN_OFFSET
            
            local fireball_id = Loci.Commands.spawn_entity({
                position = { x = spawn_x, y = spawn_y },
                blueprint = "fireball",
                entity_type = "Prop",
                move_speed = FIREBALL_SPEED,
                radius = FIREBALL_RADIUS,
                collision_filter = { layer = PROJECTILE, mask = SOLID_WALL },
                properties = {
                    owner = tostring(entity_id),
                    kind = "fireball"
                }
            })
            
            if fireball_id then
                Loci.Commands.set_velocity(fireball_id, {x = dir_x * FIREBALL_SPEED, y = dir_y * FIREBALL_SPEED})
                
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
    -- Se um deles é fireball, destruir
    local kind_a = Loci.get_entity_property(entity_a_id, "kind")
    local kind_b = Loci.get_entity_property(entity_b_id, "kind")
    
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
    local destroyed = {}
    
    for _, fb in ipairs(fireballs) do
        local keep = true
        local pos = Loci.get_entity_position(fb.id)

        if not pos or tick >= fb.expires_at then
            if not destroyed[fb.id] then
                Loci.Commands.destroy_entity(fb.id)
                destroyed[fb.id] = true
            end
            keep = false
        else
            -- Verificar colisão manual com jogadores e outras fireballs
            local near = Loci.get_entities_in_radius(pos, HIT_RADIUS)
            for _, id in ipairs(near) do
                if keep and id ~= fb.id and id ~= fb.owner and not destroyed[id] then
                    local entity_kind = Loci.get_entity_property(id, "kind")
                    if is_player(id) then
                        apply_damage(id, FIREBALL_DAMAGE)
                        if not destroyed[fb.id] then
                            Loci.Commands.destroy_entity(fb.id)
                            destroyed[fb.id] = true
                        end
                        keep = false
                    elseif entity_kind == "fireball" then
                        -- Destruir apenas a fireball com ID menor para evitar conflito
                        if fb.id < id and not destroyed[fb.id] then
                            Loci.Commands.destroy_entity(fb.id)
                            destroyed[fb.id] = true
                            keep = false
                        end
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
