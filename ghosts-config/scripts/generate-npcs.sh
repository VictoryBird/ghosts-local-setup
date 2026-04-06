#!/usr/bin/env bash
###############################################################################
# generate-npcs.sh
#
# Generates 130 NPCs for the GHOSTS NPC Framework via the GHOSTS API.
# Designed for the Meridia worldbuilding scenario (Valdoria, Krasnovia,
# Tarvek, Arventa).
#
# Usage:
#   ./generate-npcs.sh [GHOSTS_API_URL]
#
# Example:
#   ./generate-npcs.sh http://192.168.1.100:5000
#   ./generate-npcs.sh  # defaults to http://localhost:5000
###############################################################################

set -euo pipefail

API_URL="${1:-http://localhost:5000}"
API_ENDPOINT="${API_URL}/api/npcs"

TOTAL=130
CREATED=0
FAILED=0

###############################################################################
# Helper: POST an NPC to the GHOSTS API
###############################################################################
create_npc() {
    local npc_num="$1"
    local label="$2"
    local json="$3"

    echo "Creating NPC ${npc_num}/${TOTAL}: ${label}..."

    HTTP_CODE=$(curl -s -o /tmp/ghosts_npc_response.json -w "%{http_code}" \
        -X POST "${API_ENDPOINT}" \
        -H "Content-Type: application/json" \
        -d "${json}" 2>/dev/null || echo "000")

    if [[ "${HTTP_CODE}" =~ ^2[0-9][0-9]$ ]]; then
        CREATED=$((CREATED + 1))
    else
        FAILED=$((FAILED + 1))
        echo "  WARNING: HTTP ${HTTP_CODE} — NPC creation may have failed."
        if [[ -f /tmp/ghosts_npc_response.json ]]; then
            echo "  Response: $(cat /tmp/ghosts_npc_response.json | head -c 200)"
        fi
    fi
}

echo "============================================================"
echo " GHOSTS NPC Generator — Meridia Scenario"
echo " API: ${API_ENDPOINT}"
echo " Total NPCs to create: ${TOTAL}"
echo "============================================================"
echo ""

N=0

###############################################################################
#
# VALDORIA — VWA Staff (15 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Daniel Harper (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Daniel", "last": "Harper"},
    "biologicalSex": "Male",
    "birthdate": "1985-03-14",
    "email": "daniel.harper@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — IT Operations", "title": "Senior System Administrator"},
    "workstation": {"hostname": "VWA-WS-001", "ipAddress": "192.168.10.11", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Michael Torres (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Michael", "last": "Torres"},
    "biologicalSex": "Male",
    "birthdate": "1979-07-22",
    "email": "michael.torres@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Cyber Security Division", "title": "Cybersecurity Analyst"},
    "workstation": {"hostname": "VWA-WS-002", "ipAddress": "192.168.10.12", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Sarah Mitchell (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Sarah", "last": "Mitchell"},
    "biologicalSex": "Female",
    "birthdate": "1990-11-05",
    "email": "sarah.mitchell@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Strategic Communications", "title": "Communications Coordinator"},
    "workstation": {"hostname": "VWA-WS-003", "ipAddress": "192.168.10.13", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "David Chen (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "David", "last": "Chen"},
    "biologicalSex": "Male",
    "birthdate": "1988-01-30",
    "email": "david.chen@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Network Infrastructure", "title": "Network Engineer"},
    "workstation": {"hostname": "VWA-WS-004", "ipAddress": "192.168.10.14", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Emily Watson (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Emily", "last": "Watson"},
    "biologicalSex": "Female",
    "birthdate": "1992-06-18",
    "email": "emily.watson@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Administration", "title": "Administrative Coordinator"},
    "workstation": {"hostname": "VWA-WS-005", "ipAddress": "192.168.10.15", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Rachel Kim (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Rachel", "last": "Kim"},
    "biologicalSex": "Female",
    "birthdate": "1991-09-12",
    "email": "rachel.kim@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Policy and Compliance", "title": "Policy Analyst"},
    "workstation": {"hostname": "VWA-WS-006", "ipAddress": "192.168.10.16", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Jason Park (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Jason", "last": "Park"},
    "biologicalSex": "Male",
    "birthdate": "1983-04-25",
    "email": "jason.park@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — IT Operations", "title": "Database Administrator"},
    "workstation": {"hostname": "VWA-WS-007", "ipAddress": "192.168.10.17", "domain": "vwa.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Linda Reyes (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Linda", "last": "Reyes"},
    "biologicalSex": "Female",
    "birthdate": "1986-12-08",
    "email": "linda.reyes@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Human Resources", "title": "HR Manager"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Brian Yoo (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Brian", "last": "Yoo"},
    "biologicalSex": "Male",
    "birthdate": "1994-02-17",
    "email": "brian.yoo@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Cyber Security Division", "title": "Junior Security Analyst"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Christine Lowe (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Christine", "last": "Lowe"},
    "biologicalSex": "Female",
    "birthdate": "1980-08-03",
    "email": "christine.lowe@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Director Office", "title": "Deputy Director"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Mark Sullivan (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Mark", "last": "Sullivan"},
    "biologicalSex": "Male",
    "birthdate": "1975-05-20",
    "email": "mark.sullivan@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Director Office", "title": "Director"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Yuna Kwon (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Yuna", "last": "Kwon"},
    "biologicalSex": "Female",
    "birthdate": "1993-10-28",
    "email": "yuna.kwon@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — IT Operations", "title": "Help Desk Technician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Derek Owens (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Derek", "last": "Owens"},
    "biologicalSex": "Male",
    "birthdate": "1987-06-11",
    "email": "derek.owens@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Network Infrastructure", "title": "Systems Engineer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Hannah Fields (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Hannah", "last": "Fields"},
    "biologicalSex": "Female",
    "birthdate": "1996-03-07",
    "email": "hannah.fields@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Strategic Communications", "title": "Social Media Coordinator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Kevin Cho (VWA Staff)" '{
  "npcProfile": {
    "name": {"first": "Kevin", "last": "Cho"},
    "biologicalSex": "Male",
    "birthdate": "1989-11-14",
    "email": "kevin.cho@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "VWA — Logistics", "title": "Logistics Coordinator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "official"}
  }
}'

###############################################################################
#
# VALDORIA — MND Military (15 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Col. James Whitfield (MND Military)" '{
  "npcProfile": {
    "name": {"first": "James", "last": "Whitfield"},
    "biologicalSex": "Male",
    "birthdate": "1970-02-10",
    "email": "james.whitfield@mnd.valdoria.gov",
    "unit": "MND Cyber Command",
    "rank": "Colonel",
    "employment": {"department": "MND — Cyber Command", "title": "Commander"},
    "workstation": {"hostname": "MND-WS-001", "ipAddress": "192.168.20.11", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Maj. Robert Kang (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Robert", "last": "Kang"},
    "biologicalSex": "Male",
    "birthdate": "1978-08-15",
    "email": "robert.kang@mnd.valdoria.gov",
    "unit": "MND Cyber Operations Battalion",
    "rank": "Major",
    "employment": {"department": "MND — Cyber Operations", "title": "Operations Officer"},
    "workstation": {"hostname": "MND-WS-002", "ipAddress": "192.168.20.12", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Capt. Sarah Lee (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Sarah", "last": "Lee"},
    "biologicalSex": "Female",
    "birthdate": "1985-04-20",
    "email": "sarah.lee@mnd.valdoria.gov",
    "unit": "MND Cyber Defense Unit",
    "rank": "Captain",
    "employment": {"department": "MND — Cyber Defense", "title": "Defensive Cyber Operations Lead"},
    "workstation": {"hostname": "MND-WS-003", "ipAddress": "192.168.20.13", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Sgt. David Park (MND Military)" '{
  "npcProfile": {
    "name": {"first": "David", "last": "Park"},
    "biologicalSex": "Male",
    "birthdate": "1990-12-03",
    "email": "david.park@mnd.valdoria.gov",
    "unit": "MND Cyber Defense Unit",
    "rank": "Sergeant",
    "employment": {"department": "MND — Cyber Defense", "title": "Network Defense Specialist"},
    "workstation": {"hostname": "MND-WS-004", "ipAddress": "192.168.20.14", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Lt. Jennifer Choi (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Jennifer", "last": "Choi"},
    "biologicalSex": "Female",
    "birthdate": "1992-07-17",
    "email": "jennifer.choi@mnd.valdoria.gov",
    "unit": "MND Intelligence Section",
    "rank": "Lieutenant",
    "employment": {"department": "MND — Intelligence", "title": "Intelligence Analyst"},
    "workstation": {"hostname": "MND-WS-005", "ipAddress": "192.168.20.15", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Capt. Andrew Jung (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Andrew", "last": "Jung"},
    "biologicalSex": "Male",
    "birthdate": "1986-09-28",
    "email": "andrew.jung@mnd.valdoria.gov",
    "unit": "MND Signal Corps",
    "rank": "Captain",
    "employment": {"department": "MND — Signal Corps", "title": "Communications Officer"},
    "workstation": {"hostname": "MND-WS-006", "ipAddress": "192.168.20.16", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "MSG. Thomas Han (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Thomas", "last": "Han"},
    "biologicalSex": "Male",
    "birthdate": "1976-03-05",
    "email": "thomas.han@mnd.valdoria.gov",
    "unit": "MND Cyber Command",
    "rank": "Master Sergeant",
    "employment": {"department": "MND — Cyber Command", "title": "Senior NCO / Operations Sergeant"},
    "workstation": {"hostname": "MND-WS-007", "ipAddress": "192.168.20.17", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Lt. Nathan Byrne (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Nathan", "last": "Byrne"},
    "biologicalSex": "Male",
    "birthdate": "1993-01-22",
    "email": "nathan.byrne@mnd.valdoria.gov",
    "unit": "MND Cyber Operations Battalion",
    "rank": "Lieutenant",
    "employment": {"department": "MND — Cyber Operations", "title": "Offensive Cyber Operator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Sgt. Min-jun Yoon (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Min-jun", "last": "Yoon"},
    "biologicalSex": "Male",
    "birthdate": "1995-06-09",
    "email": "minjun.yoon@mnd.valdoria.gov",
    "unit": "MND Signal Corps",
    "rank": "Sergeant",
    "employment": {"department": "MND — Signal Corps", "title": "Radio Operator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Capt. Priya Nair (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Priya", "last": "Nair"},
    "biologicalSex": "Female",
    "birthdate": "1987-10-14",
    "email": "priya.nair@mnd.valdoria.gov",
    "unit": "MND Logistics Command",
    "rank": "Captain",
    "employment": {"department": "MND — Logistics", "title": "Supply Chain Officer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "PFC. Lucas Grant (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Lucas", "last": "Grant"},
    "biologicalSex": "Male",
    "birthdate": "1999-05-30",
    "email": "lucas.grant@mnd.valdoria.gov",
    "unit": "MND Cyber Defense Unit",
    "rank": "Private First Class",
    "employment": {"department": "MND — Cyber Defense", "title": "Network Monitoring Technician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Maj. Eunji Baek (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Eunji", "last": "Baek"},
    "biologicalSex": "Female",
    "birthdate": "1981-08-25",
    "email": "eunji.baek@mnd.valdoria.gov",
    "unit": "MND Intelligence Section",
    "rank": "Major",
    "employment": {"department": "MND — Intelligence", "title": "Chief Intelligence Officer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "SFC. Carlos Rivera (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Carlos", "last": "Rivera"},
    "biologicalSex": "Male",
    "birthdate": "1984-11-19",
    "email": "carlos.rivera@mnd.valdoria.gov",
    "unit": "MND Cyber Operations Battalion",
    "rank": "Sergeant First Class",
    "employment": {"department": "MND — Cyber Operations", "title": "Exploitation Analyst"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Lt. Hana Song (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Hana", "last": "Song"},
    "biologicalSex": "Female",
    "birthdate": "1994-02-06",
    "email": "hana.song@mnd.valdoria.gov",
    "unit": "MND Public Affairs",
    "rank": "Lieutenant",
    "employment": {"department": "MND — Public Affairs", "title": "Public Affairs Officer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

N=$((N+1))
create_npc $N "Cpl. Ryan Marsh (MND Military)" '{
  "npcProfile": {
    "name": {"first": "Ryan", "last": "Marsh"},
    "biologicalSex": "Male",
    "birthdate": "1997-07-13",
    "email": "ryan.marsh@mnd.valdoria.gov",
    "unit": "MND Signal Corps",
    "rank": "Corporal",
    "employment": {"department": "MND — Signal Corps", "title": "Communications Technician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "military"}
  }
}'

###############################################################################
#
# VALDORIA — GOV Liaison (1 NPC)
#
###############################################################################

N=$((N+1))
create_npc $N "GOV20190847 — VWA-MND Liaison" '{
  "npcProfile": {
    "name": {"first": "GOV20190847", "last": ""},
    "biologicalSex": "Male",
    "birthdate": "1982-05-10",
    "email": "gov20190847@mnd.valdoria.gov",
    "unit": "VWA-MND Joint Liaison Office",
    "rank": null,
    "employment": {"department": "VWA-MND Liaison Office", "title": "Liaison Officer"},
    "workstation": {"hostname": "LIAISON-WS-001", "ipAddress": "192.168.20.50", "domain": "mnd.valdoria.gov"},
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

###############################################################################
#
# VALDORIA — Citizens (50 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Mia Thompson (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Mia", "last": "Thompson"},
    "biologicalSex": "Female",
    "birthdate": "1995-04-12",
    "email": "mia.thompson@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Central Hospital", "title": "Registered Nurse"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Ethan Cruz (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Ethan", "last": "Cruz"},
    "biologicalSex": "Male",
    "birthdate": "1988-09-30",
    "email": "ethan.cruz@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Silicon Coast Tech Hub", "title": "Software Engineer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Olivia Bennett (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Olivia", "last": "Bennett"},
    "biologicalSex": "Female",
    "birthdate": "1972-01-25",
    "email": "olivia.bennett@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Public School District", "title": "High School Teacher"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Noah Kim (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Noah", "last": "Kim"},
    "biologicalSex": "Male",
    "birthdate": "2004-06-18",
    "email": "noah.kim@valdoria-univ.edu.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "University of Valdoria", "title": "Undergraduate Student"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Sophia Reyes (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Sophia", "last": "Reyes"},
    "biologicalSex": "Female",
    "birthdate": "1960-03-08",
    "email": "sophia.reyes@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Retired", "title": "Retired Teacher"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Liam Foster (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Liam", "last": "Foster"},
    "biologicalSex": "Male",
    "birthdate": "1982-11-14",
    "email": "liam.foster@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Port Callisto Shipping Co.", "title": "Logistics Manager"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Ava Morales (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Ava", "last": "Morales"},
    "biologicalSex": "Female",
    "birthdate": "1998-07-21",
    "email": "ava.morales@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Cafe Meridia", "title": "Barista"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "James O Brien (Citizen)" '{
  "npcProfile": {
    "name": {"first": "James", "last": "O\u0027Brien"},
    "biologicalSex": "Male",
    "birthdate": "1955-12-02",
    "email": "james.obrien@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Retired", "title": "Retired Electrician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Isabella Chung (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Isabella", "last": "Chung"},
    "biologicalSex": "Female",
    "birthdate": "1990-08-16",
    "email": "isabella.chung@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria National Library", "title": "Librarian"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Alexander Hayes (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Alexander", "last": "Hayes"},
    "biologicalSex": "Male",
    "birthdate": "1975-05-27",
    "email": "alexander.hayes@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Hayes General Store", "title": "Shopkeeper"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Grace Patel (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Grace", "last": "Patel"},
    "biologicalSex": "Female",
    "birthdate": "1993-02-09",
    "email": "grace.patel@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Medical Clinic", "title": "Pharmacist"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "William Andersen (Citizen)" '{
  "npcProfile": {
    "name": {"first": "William", "last": "Andersen"},
    "biologicalSex": "Male",
    "birthdate": "1968-10-31",
    "email": "william.andersen@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Post Office", "title": "Postal Worker"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Chloe Nakamura (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Chloe", "last": "Nakamura"},
    "biologicalSex": "Female",
    "birthdate": "2006-03-15",
    "email": "chloe.nakamura@valdoria-univ.edu.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris High School", "title": "Student"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Benjamin Cole (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Benjamin", "last": "Cole"},
    "biologicalSex": "Male",
    "birthdate": "1980-07-04",
    "email": "benjamin.cole@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Fire Department", "title": "Firefighter"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Emma Sinclair (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Emma", "last": "Sinclair"},
    "biologicalSex": "Female",
    "birthdate": "1987-12-22",
    "email": "emma.sinclair@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Ministry of Education", "title": "Curriculum Developer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Daniel Ortega (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Daniel", "last": "Ortega"},
    "biologicalSex": "Male",
    "birthdate": "1991-04-17",
    "email": "daniel.ortega@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Silicon Coast Robotics", "title": "Mechanical Engineer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Hye-jin Moon (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Hye-jin", "last": "Moon"},
    "biologicalSex": "Female",
    "birthdate": "1996-09-03",
    "email": "hyejin.moon@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Art Gallery", "title": "Gallery Curator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Robert Quinn (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Robert", "last": "Quinn"},
    "biologicalSex": "Male",
    "birthdate": "1950-08-11",
    "email": "robert.quinn@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Retired", "title": "Retired Factory Worker"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Lily Tran (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Lily", "last": "Tran"},
    "biologicalSex": "Female",
    "birthdate": "1985-06-28",
    "email": "lily.tran@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris General Hospital", "title": "Pediatrician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Marcus Webb (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Marcus", "last": "Webb"},
    "biologicalSex": "Male",
    "birthdate": "1977-03-19",
    "email": "marcus.webb@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Webb Construction LLC", "title": "Construction Foreman"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Naomi Fischer (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Naomi", "last": "Fischer"},
    "biologicalSex": "Female",
    "birthdate": "2003-01-07",
    "email": "naomi.fischer@valdoria-univ.edu.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "University of Valdoria", "title": "Graduate Student — Computer Science"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "George Palmer (Citizen)" '{
  "npcProfile": {
    "name": {"first": "George", "last": "Palmer"},
    "biologicalSex": "Male",
    "birthdate": "1963-11-20",
    "email": "george.palmer@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Palmer Auto Repair", "title": "Auto Mechanic"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Soo-yeon Jang (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Soo-yeon", "last": "Jang"},
    "biologicalSex": "Female",
    "birthdate": "1989-05-14",
    "email": "sooyeon.jang@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Central Bank", "title": "Financial Analyst"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Tyler Brooks (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Tyler", "last": "Brooks"},
    "biologicalSex": "Male",
    "birthdate": "2000-10-05",
    "email": "tyler.brooks@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Express Delivery", "title": "Delivery Driver"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Margaret Lindstrom (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Margaret", "last": "Lindstrom"},
    "biologicalSex": "Female",
    "birthdate": "1952-04-30",
    "email": "margaret.lindstrom@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Retired", "title": "Retired School Principal"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Chris Yang (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Chris", "last": "Yang"},
    "biologicalSex": "Male",
    "birthdate": "1994-08-22",
    "email": "chris.yang@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Tech Solutions", "title": "IT Support Specialist"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Aisha Rahman (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Aisha", "last": "Rahman"},
    "biologicalSex": "Female",
    "birthdate": "1984-02-14",
    "email": "aisha.rahman@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Family Clinic", "title": "General Practitioner"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Peter Wallace (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Peter", "last": "Wallace"},
    "biologicalSex": "Male",
    "birthdate": "1971-06-03",
    "email": "peter.wallace@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Police Department", "title": "Police Detective"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Ji-woo Shin (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Ji-woo", "last": "Shin"},
    "biologicalSex": "Male",
    "birthdate": "2005-09-18",
    "email": "jiwoo.shin@valdoria-univ.edu.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Academy", "title": "Student"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Diana Voss (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Diana", "last": "Voss"},
    "biologicalSex": "Female",
    "birthdate": "1978-12-01",
    "email": "diana.voss@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Voss Legal Partners", "title": "Attorney"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Samuel Grant (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Samuel", "last": "Grant"},
    "biologicalSex": "Male",
    "birthdate": "1966-07-15",
    "email": "samuel.grant@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Water Authority", "title": "Water Treatment Operator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Yuri Takeda (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Yuri", "last": "Takeda"},
    "biologicalSex": "Female",
    "birthdate": "1992-03-26",
    "email": "yuri.takeda@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris International School", "title": "Elementary Teacher"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Andrew Fletcher (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Andrew", "last": "Fletcher"},
    "biologicalSex": "Male",
    "birthdate": "1983-01-09",
    "email": "andrew.fletcher@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Fletcher Plumbing Services", "title": "Plumber"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Natalie Hwang (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Natalie", "last": "Hwang"},
    "biologicalSex": "Female",
    "birthdate": "1997-11-08",
    "email": "natalie.hwang@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Digital Marketing", "title": "Marketing Coordinator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Harold Price (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Harold", "last": "Price"},
    "biologicalSex": "Male",
    "birthdate": "1948-06-25",
    "email": "harold.price@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Retired", "title": "Retired Civil Engineer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Jenny Liu (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Jenny", "last": "Liu"},
    "biologicalSex": "Female",
    "birthdate": "1986-04-03",
    "email": "jenny.liu@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Dental Clinic", "title": "Dentist"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Kenneth Ross (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Kenneth", "last": "Ross"},
    "biologicalSex": "Male",
    "birthdate": "1973-09-17",
    "email": "kenneth.ross@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Electrical Utility", "title": "Electrical Technician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Seo-yun Park (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Seo-yun", "last": "Park"},
    "biologicalSex": "Female",
    "birthdate": "2001-08-12",
    "email": "seoyun.park@valdoria-univ.edu.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "University of Valdoria", "title": "Graduate Student — Political Science"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Frank Dunn (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Frank", "last": "Dunn"},
    "biologicalSex": "Male",
    "birthdate": "1958-02-28",
    "email": "frank.dunn@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Dunn Hardware", "title": "Hardware Store Owner"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Monica Alvarez (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Monica", "last": "Alvarez"},
    "biologicalSex": "Female",
    "birthdate": "1981-10-06",
    "email": "monica.alvarez@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Social Services", "title": "Social Worker"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Jake Lawson (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Jake", "last": "Lawson"},
    "biologicalSex": "Male",
    "birthdate": "1999-05-20",
    "email": "jake.lawson@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Port Callisto Docks", "title": "Dock Worker"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Eun-bi Lim (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Eun-bi", "last": "Lim"},
    "biologicalSex": "Female",
    "birthdate": "1990-07-29",
    "email": "eunbi.lim@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Lim Photography Studio", "title": "Photographer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Douglas Meyer (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Douglas", "last": "Meyer"},
    "biologicalSex": "Male",
    "birthdate": "1965-12-14",
    "email": "douglas.meyer@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Transit Authority", "title": "Bus Driver"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Priya Sharma (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Priya", "last": "Sharma"},
    "biologicalSex": "Female",
    "birthdate": "1994-03-11",
    "email": "priya.sharma@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Silicon Coast Biotech", "title": "Research Scientist"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Victor Nguyen (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Victor", "last": "Nguyen"},
    "biologicalSex": "Male",
    "birthdate": "1979-08-08",
    "email": "victor.nguyen@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Nguyen Family Restaurant", "title": "Restaurant Owner"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Claire Donovan (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Claire", "last": "Donovan"},
    "biologicalSex": "Female",
    "birthdate": "1970-05-19",
    "email": "claire.donovan@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Community Center", "title": "Community Organizer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Ryan Cho (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Ryan", "last": "Cho"},
    "biologicalSex": "Male",
    "birthdate": "2007-11-25",
    "email": "ryan.cho@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris High School", "title": "Student"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Sandra Eriksen (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Sandra", "last": "Eriksen"},
    "biologicalSex": "Female",
    "birthdate": "1974-01-16",
    "email": "sandra.eriksen@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Ministry of Health", "title": "Public Health Inspector"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Tae-hyun Kwon (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Tae-hyun", "last": "Kwon"},
    "biologicalSex": "Male",
    "birthdate": "1988-04-07",
    "email": "taehyun.kwon@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Telecom", "title": "Telecom Technician"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Angela Whitmore (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Angela", "last": "Whitmore"},
    "biologicalSex": "Female",
    "birthdate": "1976-10-22",
    "email": "angela.whitmore@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Department of Labor", "title": "Employment Counselor"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Raymond Suh (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Raymond", "last": "Suh"},
    "biologicalSex": "Male",
    "birthdate": "1969-07-03",
    "email": "raymond.suh@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Public Transit", "title": "Train Conductor"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Jasmine Okafor (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Jasmine", "last": "Okafor"},
    "biologicalSex": "Female",
    "birthdate": "2002-11-09",
    "email": "jasmine.okafor@valdoria-univ.edu.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "University of Valdoria", "title": "Undergraduate Student — Nursing"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Howard Chen (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Howard", "last": "Chen"},
    "biologicalSex": "Male",
    "birthdate": "1953-06-15",
    "email": "howard.chen@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Retired", "title": "Retired Accountant"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Lauren Castellano (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Lauren", "last": "Castellano"},
    "biologicalSex": "Female",
    "birthdate": "1991-02-28",
    "email": "lauren.castellano@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Veterinary Hospital", "title": "Veterinarian"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Steven Rowe (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Steven", "last": "Rowe"},
    "biologicalSex": "Male",
    "birthdate": "1984-09-19",
    "email": "steven.rowe@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Silicon Coast Energy Corp.", "title": "Electrical Engineer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Mi-rae Jung (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Mi-rae", "last": "Jung"},
    "biologicalSex": "Female",
    "birthdate": "1997-04-14",
    "email": "mirae.jung@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Cultural Foundation", "title": "Event Coordinator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Dennis Crawford (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Dennis", "last": "Crawford"},
    "biologicalSex": "Male",
    "birthdate": "1962-01-07",
    "email": "dennis.crawford@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Crawford Bakery", "title": "Baker / Shop Owner"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Tamara Ellis (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Tamara", "last": "Ellis"},
    "biologicalSex": "Female",
    "birthdate": "1980-08-30",
    "email": "tamara.ellis@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Environmental Agency", "title": "Environmental Inspector"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Jun-ho Baek (Citizen)" '{
  "npcProfile": {
    "name": {"first": "Jun-ho", "last": "Baek"},
    "biologicalSex": "Male",
    "birthdate": "2008-03-21",
    "email": "junho.baek@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Middle School", "title": "Student"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "valdoria", "role": "citizen"}
  }
}'

###############################################################################
#
# VALDORIA — Media (5 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Catherine Wells (VNB Reporter)" '{
  "npcProfile": {
    "name": {"first": "Catherine", "last": "Wells"},
    "biologicalSex": "Female",
    "birthdate": "1980-06-14",
    "email": "catherine.wells@vnb.valdoria.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria National Broadcasting (VNB)", "title": "Senior Anchor"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "media"}
  }
}'

N=$((N+1))
create_npc $N "Marcus Yang (VNB Reporter)" '{
  "npcProfile": {
    "name": {"first": "Marcus", "last": "Yang"},
    "biologicalSex": "Male",
    "birthdate": "1985-11-02",
    "email": "marcus.yang@vnb.valdoria.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria National Broadcasting (VNB)", "title": "Cybersecurity Correspondent"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "media"}
  }
}'

N=$((N+1))
create_npc $N "Joanna Kirk (Elaris Tribune)" '{
  "npcProfile": {
    "name": {"first": "Joanna", "last": "Kirk"},
    "biologicalSex": "Female",
    "birthdate": "1978-03-27",
    "email": "joanna.kirk@elaris-tribune.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Tribune", "title": "Editor-in-Chief"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "media"}
  }
}'

N=$((N+1))
create_npc $N "David Seo (Elaris Tribune)" '{
  "npcProfile": {
    "name": {"first": "David", "last": "Seo"},
    "biologicalSex": "Male",
    "birthdate": "1990-09-15",
    "email": "david.seo@elaris-tribune.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Elaris Tribune", "title": "Investigative Journalist"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "media"}
  }
}'

N=$((N+1))
create_npc $N "Helen Drake (VNB Reporter)" '{
  "npcProfile": {
    "name": {"first": "Helen", "last": "Drake"},
    "biologicalSex": "Female",
    "birthdate": "1982-07-08",
    "email": "helen.drake@vnb.valdoria.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria National Broadcasting (VNB)", "title": "Field Reporter — Defense"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "media"}
  }
}'

###############################################################################
#
# VALDORIA — Official Accounts (5 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Valdoria Government (Official)" '{
  "npcProfile": {
    "name": {"first": "Valdoria", "last": "Government"},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@gov.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "Government of Valdoria", "title": "Official Government Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "MOIS (Official)" '{
  "npcProfile": {
    "name": {"first": "MOIS", "last": ""},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@mois.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "Ministry of Internal Security (MOIS)", "title": "Official MOIS Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "MND (Official)" '{
  "npcProfile": {
    "name": {"first": "MND", "last": ""},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@mnd.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "Ministry of National Defense (MND)", "title": "Official MND Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "CDC (Official)" '{
  "npcProfile": {
    "name": {"first": "CDC", "last": ""},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@cdc.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "Cyber Defense Center (CDC)", "title": "Official CDC Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "VWA (Official)" '{
  "npcProfile": {
    "name": {"first": "VWA", "last": ""},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@vwa.valdoria.gov",
    "unit": null,
    "rank": null,
    "employment": {"department": "Valdoria Water Authority (VWA)", "title": "Official VWA Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "valdoria", "role": "official"}
  }
}'

###############################################################################
#
# KRASNOVIA — Official Accounts (3 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Krasnovia Government (Official)" '{
  "npcProfile": {
    "name": {"first": "Krasnovia", "last": "Government"},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@gov.krasnovia.kn",
    "unit": null,
    "rank": null,
    "employment": {"department": "Government of Krasnovia", "title": "Official Government Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "krasnovia", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "State Cyber Command — SCC (Official)" '{
  "npcProfile": {
    "name": {"first": "State Cyber Command", "last": "(SCC)"},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@scc.krasnovia.kn",
    "unit": null,
    "rank": null,
    "employment": {"department": "State Cyber Command (SCC)", "title": "Official SCC Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "krasnovia", "role": "official"}
  }
}'

N=$((N+1))
create_npc $N "Krasnovia Today (Official)" '{
  "npcProfile": {
    "name": {"first": "Krasnovia", "last": "Today"},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "editor@krasnovia-today.kn",
    "unit": null,
    "rank": null,
    "employment": {"department": "Krasnovia Today (State Media)", "title": "Official Media Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "krasnovia", "role": "media"}
  }
}'

###############################################################################
#
# KRASNOVIA — Disguised Accounts (10 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Aleksei Morozov (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Aleksei", "last": "Morozov"},
    "biologicalSex": "Male",
    "birthdate": "1991-03-14",
    "email": "alex.morozov@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "IT Consultant"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Irina Volkov (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Irina", "last": "Volkov"},
    "biologicalSex": "Female",
    "birthdate": "1988-07-22",
    "email": "irina.volkov@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Self-Employed", "title": "Graphic Designer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Dmitri Petrov (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Dmitri", "last": "Petrov"},
    "biologicalSex": "Male",
    "birthdate": "1985-11-30",
    "email": "dmitri.petrov@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Port Callisto Trading", "title": "Import Specialist"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Natasha Kuznetsova (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Natasha", "last": "Kuznetsova"},
    "biologicalSex": "Female",
    "birthdate": "1993-05-18",
    "email": "natasha.k@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "Content Creator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Viktor Sokolov (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Viktor", "last": "Sokolov"},
    "biologicalSex": "Male",
    "birthdate": "1990-09-05",
    "email": "viktor.sokolov@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "Blogger"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Olga Fedorova (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Olga", "last": "Fedorova"},
    "biologicalSex": "Female",
    "birthdate": "1995-01-28",
    "email": "olga.fedorova@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "Translator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Sergei Kozlov (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Sergei", "last": "Kozlov"},
    "biologicalSex": "Male",
    "birthdate": "1987-04-12",
    "email": "sergei.kozlov@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Self-Employed", "title": "Small Business Owner"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Yelena Popova (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Yelena", "last": "Popova"},
    "biologicalSex": "Female",
    "birthdate": "1992-08-17",
    "email": "yelena.popova@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "Freelance Writer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Andrei Novikov (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Andrei", "last": "Novikov"},
    "biologicalSex": "Male",
    "birthdate": "1989-12-03",
    "email": "andrei.novikov@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Independent", "title": "Political Commentator"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Marina Ivanova (Disguised)" '{
  "npcProfile": {
    "name": {"first": "Marina", "last": "Ivanova"},
    "biologicalSex": "Female",
    "birthdate": "1994-06-21",
    "email": "marina.ivanova@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Self-Employed", "title": "Online Retailer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "krasnovia", "role": "disguised"}
  }
}'

###############################################################################
#
# KRASNOVIA — Bot Accounts (7 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Alex K. (Bot)" '{
  "npcProfile": {
    "name": {"first": "Alex", "last": "K."},
    "biologicalSex": "Male",
    "birthdate": "1996-02-10",
    "email": "alexk9281@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

N=$((N+1))
create_npc $N "Jordan M. (Bot)" '{
  "npcProfile": {
    "name": {"first": "Jordan", "last": "M."},
    "biologicalSex": "Female",
    "birthdate": "1998-05-14",
    "email": "jordanm4452@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

N=$((N+1))
create_npc $N "Sam Lee (Bot)" '{
  "npcProfile": {
    "name": {"first": "Sam", "last": "Lee"},
    "biologicalSex": "Male",
    "birthdate": "1997-08-23",
    "email": "samlee7731@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

N=$((N+1))
create_npc $N "Pat S. (Bot)" '{
  "npcProfile": {
    "name": {"first": "Pat", "last": "S."},
    "biologicalSex": "Unknown",
    "birthdate": "1995-11-07",
    "email": "pats2209@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

N=$((N+1))
create_npc $N "Casey R. (Bot)" '{
  "npcProfile": {
    "name": {"first": "Casey", "last": "R."},
    "biologicalSex": "Female",
    "birthdate": "1999-03-19",
    "email": "caseyr8844@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

N=$((N+1))
create_npc $N "Robin J. (Bot)" '{
  "npcProfile": {
    "name": {"first": "Robin", "last": "J."},
    "biologicalSex": "Unknown",
    "birthdate": "1997-01-25",
    "email": "robinj6650@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

N=$((N+1))
create_npc $N "Taylor W. (Bot)" '{
  "npcProfile": {
    "name": {"first": "Taylor", "last": "W."},
    "biologicalSex": "Unknown",
    "birthdate": "1998-09-11",
    "email": "taylorw3317@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "", "title": ""},
    "workstation": null,
    "attributes": {"influence_tier": "3", "country": "krasnovia", "role": "bot"}
  }
}'

###############################################################################
#
# TARVEK — Official (1 NPC)
#
###############################################################################

N=$((N+1))
create_npc $N "Tarvek Government (Official)" '{
  "npcProfile": {
    "name": {"first": "Tarvek", "last": "Government"},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@gov.tarvek.tk",
    "unit": null,
    "rank": null,
    "employment": {"department": "Government of Tarvek", "title": "Official Government Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "tarvek", "role": "official"}
  }
}'

###############################################################################
#
# TARVEK — GORGON-linked (2 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "GORGON_Cipher (GORGON)" '{
  "npcProfile": {
    "name": {"first": "GORGON", "last": "Cipher"},
    "biologicalSex": "Unknown",
    "birthdate": "1993-06-06",
    "email": "gorgon_cipher@darknet.tk",
    "unit": null,
    "rank": null,
    "employment": {"department": "GORGON Collective", "title": "Threat Actor"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "tarvek", "role": "gorgon"}
  }
}'

N=$((N+1))
create_npc $N "Spectr3 (GORGON)" '{
  "npcProfile": {
    "name": {"first": "Spectr3", "last": ""},
    "biologicalSex": "Unknown",
    "birthdate": "1995-10-31",
    "email": "spectr3@darknet.tk",
    "unit": null,
    "rank": null,
    "employment": {"department": "GORGON Collective", "title": "Hacker / Operator"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "tarvek", "role": "gorgon"}
  }
}'

###############################################################################
#
# TARVEK — Disguised (2 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Murat Demir (Disguised — Tarvek)" '{
  "npcProfile": {
    "name": {"first": "Murat", "last": "Demir"},
    "biologicalSex": "Male",
    "birthdate": "1990-04-09",
    "email": "murat.demir@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "Web Developer"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "tarvek", "role": "disguised"}
  }
}'

N=$((N+1))
create_npc $N "Elif Arslan (Disguised — Tarvek)" '{
  "npcProfile": {
    "name": {"first": "Elif", "last": "Arslan"},
    "biologicalSex": "Female",
    "birthdate": "1994-12-20",
    "email": "elif.arslan@elaris-mail.vd",
    "unit": null,
    "rank": null,
    "employment": {"department": "Freelance", "title": "Social Media Manager"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "tarvek", "role": "disguised"}
  }
}'

###############################################################################
#
# ARVENTA — Official (1 NPC)
#
###############################################################################

N=$((N+1))
create_npc $N "Arventa Government (Official)" '{
  "npcProfile": {
    "name": {"first": "Arventa", "last": "Government"},
    "biologicalSex": "Unknown",
    "birthdate": "2000-01-01",
    "email": "official@gov.arventa.av",
    "unit": null,
    "rank": null,
    "employment": {"department": "Government of Arventa", "title": "Official Government Account"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "arventa", "role": "official"}
  }
}'

###############################################################################
#
# ARVENTA — Media (1 NPC)
#
###############################################################################

N=$((N+1))
create_npc $N "Lucia Ferrante (Arventa Media)" '{
  "npcProfile": {
    "name": {"first": "Lucia", "last": "Ferrante"},
    "biologicalSex": "Female",
    "birthdate": "1983-05-12",
    "email": "lucia.ferrante@mnn-international.av",
    "unit": null,
    "rank": null,
    "employment": {"department": "Meridia News Network (MNN)", "title": "International Correspondent"},
    "workstation": null,
    "attributes": {"influence_tier": "1", "country": "arventa", "role": "media"}
  }
}'

###############################################################################
#
# ARVENTA — Citizens (3 NPCs)
#
###############################################################################

N=$((N+1))
create_npc $N "Marco Bianchi (Arventa Citizen)" '{
  "npcProfile": {
    "name": {"first": "Marco", "last": "Bianchi"},
    "biologicalSex": "Male",
    "birthdate": "1986-09-30",
    "email": "marco.bianchi@arventa-mail.av",
    "unit": null,
    "rank": null,
    "employment": {"department": "University of Arventa", "title": "Political Science Professor"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "arventa", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Sofia Navarro (Arventa Citizen)" '{
  "npcProfile": {
    "name": {"first": "Sofia", "last": "Navarro"},
    "biologicalSex": "Female",
    "birthdate": "1992-01-17",
    "email": "sofia.navarro@arventa-mail.av",
    "unit": null,
    "rank": null,
    "employment": {"department": "Arventa Red Cross Chapter", "title": "Humanitarian Aid Worker"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "arventa", "role": "citizen"}
  }
}'

N=$((N+1))
create_npc $N "Luca Greco (Arventa Citizen)" '{
  "npcProfile": {
    "name": {"first": "Luca", "last": "Greco"},
    "biologicalSex": "Male",
    "birthdate": "1978-04-05",
    "email": "luca.greco@arventa-mail.av",
    "unit": null,
    "rank": null,
    "employment": {"department": "Arventa Chamber of Commerce", "title": "Trade Liaison"},
    "workstation": null,
    "attributes": {"influence_tier": "2", "country": "arventa", "role": "citizen"}
  }
}'

###############################################################################
# Summary
###############################################################################

echo ""
echo "============================================================"
echo " NPC Generation Complete"
echo "============================================================"
echo " Total attempted:  ${TOTAL}"
echo " Successfully created: ${CREATED}"
echo " Failed:               ${FAILED}"
echo "============================================================"

if [[ ${FAILED} -gt 0 ]]; then
    echo ""
    echo "WARNING: ${FAILED} NPC(s) failed to create. Check the GHOSTS API logs."
    exit 1
fi

exit 0
