#!/usr/bin/env bash
###############################################################################
# patch-influence-tier.sh
#
# Patches GHOSTS API source code to implement influence tier system:
#   Tier 1 (Government/Media): 30 connections, 2x knowledge transfer, 1.5x belief influence
#   Tier 2 (Citizens): 10 connections, 1x (default)
#   Tier 3 (Bots): 3 connections, no belief change (fixed), amplification only
#
# Usage: ./patch-influence-tier.sh /path/to/GHOSTS/src
###############################################################################

set -euo pipefail

GHOSTS_SRC="${1:?Usage: $0 /path/to/GHOSTS/src}"

SOCIAL_GRAPH="${GHOSTS_SRC}/Ghosts.Api/Infrastructure/Animations/AnimationDefinitions/SocialGraphJob.cs"
SOCIAL_BELIEF="${GHOSTS_SRC}/Ghosts.Api/Infrastructure/Animations/AnimationDefinitions/SocialBeliefJob.cs"

if [ ! -f "$SOCIAL_GRAPH" ]; then
    echo "ERROR: SocialGraphJob.cs not found at $SOCIAL_GRAPH"
    exit 1
fi

if [ ! -f "$SOCIAL_BELIEF" ]; then
    echo "ERROR: SocialBeliefJob.cs not found at $SOCIAL_BELIEF"
    exit 1
fi

echo "Patching GHOSTS source for influence tier system..."

# Backup originals
cp "$SOCIAL_GRAPH" "${SOCIAL_GRAPH}.bak"
cp "$SOCIAL_BELIEF" "${SOCIAL_BELIEF}.bak"

###############################################################################
# Patch SocialGraphJob.cs
###############################################################################
echo "  -> Patching SocialGraphJob.cs..."

# 1. Add GetInfluenceTier helper method before the last closing brace of the class
# Find the line with "private string TryLearn" and insert helper before it
python3 << PYEOF
import re

with open("$SOCIAL_GRAPH", "r") as f:
    content = f.read()

# Add helper method to get influence tier from NPC attributes
helper_method = '''
    private static int GetConnectionCountByTier(NpcRecord npc)
    {
        var tier = GetInfluenceTier(npc);
        return tier switch
        {
            1 => 30,  // Government, Media — high reach
            3 => 3,   // Bots — minimal connections
            _ => 10   // Citizens — default
        };
    }

    private static int GetInfluenceTier(NpcRecord npc)
    {
        if (npc?.NpcProfile?.Attributes == null) return 2;
        if (npc.NpcProfile.Attributes.TryGetValue("influence_tier", out var tierStr))
        {
            if (int.TryParse(tierStr, out var tier)) return tier;
        }
        return 2; // default to citizen tier
    }

    private static double GetKnowledgeTransferMultiplier(NpcRecord npc)
    {
        var tier = GetInfluenceTier(npc);
        return tier switch
        {
            1 => 2.0,  // Government/Media — 2x influence
            3 => 0.1,  // Bots — almost no independent knowledge
            _ => 1.0   // Citizens — default
        };
    }

'''

# Insert before TryLearn method
content = content.replace(
    "    private string TryLearn(",
    helper_method + "    private string TryLearn("
)

# 2. Modify InitializeConnectionsAsync to use tier-based connection count
content = content.replace(
    ".Take(10)",
    ".Take(GetConnectionCountByTier(npc))"
)

# 3. Modify TryLearn to apply influence tier multiplier
content = content.replace(
    "if (!chance.ChanceOfThisValue()) return string.Empty;",
    "chance *= GetKnowledgeTransferMultiplier(npc);\n        if (!chance.ChanceOfThisValue()) return string.Empty;"
)

with open("$SOCIAL_GRAPH", "w") as f:
    f.write(content)

print("  -> SocialGraphJob.cs patched successfully")
PYEOF

###############################################################################
# Patch SocialBeliefJob.cs
###############################################################################
echo "  -> Patching SocialBeliefJob.cs..."

python3 << PYEOF
import re

with open("$SOCIAL_BELIEF", "r") as f:
    content = f.read()

# 1. Add GetInfluenceTier helper (same as in SocialGraphJob)
helper_method = '''
    private static int GetInfluenceTier(NpcRecord npc)
    {
        if (npc?.NpcProfile?.Attributes == null) return 2;
        if (npc.NpcProfile.Attributes.TryGetValue("influence_tier", out var tierStr))
        {
            if (int.TryParse(tierStr, out var tier)) return tier;
        }
        return 2;
    }

    private static bool IsBotNpc(NpcRecord npc)
    {
        if (npc?.NpcProfile?.Attributes == null) return false;
        if (npc.NpcProfile.Attributes.TryGetValue("role", out var role))
        {
            return role == "bot";
        }
        return false;
    }

'''

# Insert before the Step method
content = content.replace(
    "    private void Step(",
    helper_method + "    private void Step("
)

# 2. Add bot skip logic at the start of Step method
# After "if (npcWithData == null) return;" add bot check
content = content.replace(
    "if (npcWithData == null) return;",
    '''if (npcWithData == null) return;

        // Bots (Tier 3) don't change beliefs — they only amplify
        if (IsBotNpc(npcWithData)) return;'''
)

# 3. Modify connection initialization to use tier-based count
content = content.replace(
    ".Take(10)\n                .ToList();",
    ".Take(GetInfluenceTier(npcWithData) == 1 ? 30 : GetInfluenceTier(npcWithData) == 3 ? 3 : 10)\n                .ToList();"
)

# 4. Add neighbor influence to belief update
# Replace the simple self-referential Bayes update with neighbor-influenced version
old_bayes = '''var bayes = new Bayes(npcWithData.CurrentStep, belief.Likelihood, belief.Posterior,
                1 - belief.Likelihood, 1 - belief.Posterior);'''

new_bayes = '''// Aggregate neighbor influence on likelihood
            var neighborInfluence = 0.0m;
            var neighborCount = 0;
            if (npcWithData.Connections != null && npcWithData.Connections.Any())
            {
                foreach (var conn in npcWithData.Connections.Take(5))
                {
                    var neighbor = _context.Npcs
                        .Include(n => n.Beliefs)
                        .FirstOrDefault(n => n.Id == conn.ConnectedNpcId);
                    if (neighbor?.Beliefs != null && neighbor.Beliefs.Any())
                    {
                        var neighborBelief = neighbor.Beliefs.MaxBy(b => b.Step);
                        if (neighborBelief != null)
                        {
                            // Weight by relationship status and neighbor's influence tier
                            var tierWeight = GetInfluenceTier(neighbor) == 1 ? 1.5m : 1.0m;
                            var relWeight = Math.Max(0.1m, (conn.RelationshipStatus + 1.0m) / 2.0m);
                            neighborInfluence += neighborBelief.Posterior * tierWeight * relWeight;
                            neighborCount++;
                        }
                    }
                }
            }

            // Blend own likelihood with neighbor influence
            var adjustedLikelihood = belief.Likelihood;
            if (neighborCount > 0)
            {
                var avgNeighborPosterior = neighborInfluence / neighborCount;
                adjustedLikelihood = belief.Likelihood * 0.7m + avgNeighborPosterior * 0.3m;
            }

            var bayes = new Bayes(npcWithData.CurrentStep, adjustedLikelihood, belief.Posterior,
                1 - adjustedLikelihood, 1 - belief.Posterior);'''

content = content.replace(old_bayes, new_bayes)

# 5. Update belief topics to Meridia scenario
content = content.replace(
    '"I should vote for candidate A", "I should vote for candidate B"',
    '"I trust the Valdoria government", "The cyber attacks are Krasnovia fault", "Valdoria should negotiate peace"'
)

with open("$SOCIAL_BELIEF", "w") as f:
    f.write(content)

print("  -> SocialBeliefJob.cs patched successfully")
PYEOF

echo ""
echo "============================================"
echo "  Influence Tier Patch Complete"
echo "============================================"
echo ""
echo "  Tier 1 (Government/Media):"
echo "    - 30 connections, 2x knowledge transfer, 1.5x belief weight"
echo "  Tier 2 (Citizens):"
echo "    - 10 connections, default behavior"
echo "  Tier 3 (Bots):"
echo "    - 3 connections, no belief change, amplification only"
echo ""
echo "  Belief topics updated to Meridia scenario:"
echo "    - I trust the Valdoria government"
echo "    - The cyber attacks are Krasnovia fault"
echo "    - Valdoria should negotiate peace"
echo ""
echo "  Rebuild API to apply: docker compose build ghosts-api"
echo "============================================"
