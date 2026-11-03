# RoWorld: path to 80% territory

The win condition for this plan is `state:land_share(localOwnerId) >= 0.80` in an active match. A sent order is not a captured tile. Record territory, troop reserve, income, structures, and the strongest rival after each checkpoint.

| Checkpoint | Territory | Required behavior | Evidence |
| --- | ---: | --- | --- |
| Establish | Spawn to 2% | Expand into neutral land or a weak adjacent owner, build the first city and income source, and keep an army reserve. | Territory and income increase without losing the nation. |
| Grow | 2% to 15% | Add factories and ports when affordable, expand against reachable owners, avoid spending the army into a counterattack. | Territory, income, and troop capacity rise together. |
| Consolidate | 15% to 40% | Add SAMs and launchers, upgrade cities and factories, place SAMs near economic assets without clustering, prefer land attacks on a shared border, strike a rival only if it threatens the lead. | Defensive structures exist, income holds, and the nation keeps growing. |
| Global campaign | 40% to 80% | Prefer large, lightly defended territories and reachable factories, ports, and cities. Use boats when a land frontier is unavailable, preferring landings near our ports. Observe each attack before repeating it. Cool down an unsuccessful target for 90 seconds and try another. | Each successful campaign raises our tiles and lowers the target's tiles. |
| Win | 80% or more | Stop issuing new orders while the game resolves the win. | The game reports the local owner as winner. |

## Decision flow

1. Read the live nation and game phase. Do nothing if the nation is absent, eliminated, or the match has ended.
2. If the nation has reached 80%, stop sending orders.
3. If a large incoming attack threatens the nation, fortify the border and preserve troops.
4. Spend affordable gold on missing city, port, factory, SAM, or launcher capacity. Upgrade existing infrastructure when troop capacity or income lags. Place new SAMs near cities, ports, and factories while spreading them away from existing SAMs.
5. Reserve strategic strikes for a rival holding at least 25% of the map and at least 80% of our own share.
6. Choose a legal land target before a boat target for the same owner. Rank safe targets by enemy troops per territory tile, strategic structures reachable at the target, and sailing distance from our ports. This prevents repeated landings on tiny islands while larger, weakly defended targets are available.
7. Keep an army reserve after every attack. At 40% share and above, use 15% of troop capacity as the reserve floor so an inflated city cap does not stop the final campaign. For a sea landing, consider enemy troop density as well as total troops. Send no second attack to an owner while the first is being evaluated.
8. Treat an attack as captured only when our territory increases and the target's territory decreases. After 25 seconds on land or 45 seconds at sea without that result, avoid the owner for 90 seconds.

## Verification gate

Policy tests must pass before live testing. A complete live acceptance run starts with a newly spawned nation, records the checkpoints above, and ends when the game reports the local nation as winner. Territory should be sampled throughout the run because attacks can still change the displayed share after the winner is set. An earlier run reached about 40%; a later run reported the local nation as winner after a measured 78.7% share shortly before the game ended. The exact 80% crossing was not captured by that polling interval.
