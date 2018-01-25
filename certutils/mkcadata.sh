#!/bin/sh
#
# vim: set ts=2 nowrap
#
# This utliity gathers the data from the end-entity certs and creates an index.dat file
# for the responders to read.
#
# It then creates tar files with the artfacts needed to run a responder
#
. ./revoke.sh

CWD=$(pwd)
PIVGEN1_DEST=$CWD/data/database/piv-gen1-2-index.txt
PIVGEN3_DEST=$CWD/data/database/piv-gen3-index.txt
PIVIGEN1_DEST=$CWD/data/database/pivi-gen1-2-index.txt
PIVIGEN3_DEST=$CWD/data/database/pivi-gen3-index.txt

PIVGEN1_LOCAL=$CWD/piv-gen1-2-index.txt
PIVGEN3_LOCAL=$CWD/piv-gen3-index.txt
PIVIGEN1_LOCAL=$CWD/pivi-gen1-2-index.txt
PIVIGEN3_LOCAL=$CWD/pivi-gen3-index.txt

cp $PIVGEN1_DEST $PIVGEN1_LOCAL
cp $PIVGEN3_DEST $PIVGEN3_LOCAL
cp $PIVIGEN1_DEST $PIVIGEN1_LOCAL
cp $PIVIGEN3_DEST $PIVIGEN3_LOCAL

cp -p ../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/*.crt data/pem
cp -p ../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/*.p12 data
rm -f /tmp/hashes.txt

SIGNCERTS="ICAM_Test_Card_PIV_Signing_CA_-_gold_gen1-2.crt \
	ICAM_Test_Card_PIV_Signing_CA_-_gold_gen3.crt \
	ICAM_Test_Card_PIV-I_Signing_CA_-_gold_gen3.crt"

CONTCERTS="ICAM_Test_Card_PIV_Content_Signer_-_gold_gen1-2.p12 \
	ICAM_Test_Card_PIV_Revoked_Content_Signer_gen1-2.p12 \
	ICAM_Test_Card_PIV_Content_Signer_-_gold_gen3.p12 \
	ICAM_Test_Card_PIV_Content_Signer_Expiring_-_gold_gen3.p12 \
	ICAM_Test_Card_PIV-I_Content_Signer_-_gold_gen1-2.p12 \
	ICAM_Test_Card_PIV-I_Content_Signer_-_gold_gen3.p12"

OCSPCERTS="ICAM_Test_Card_PIV_OCSP_Expired_Signer_gen3.p12 \
	ICAM_Test_Card_PIV_OCSP_Invalid_Sig_Signer_gen3.p12 \
	ICAM_Test_Card_PIV_OCSP_Revoked_Signer_No_Check_Not_Present_gen3.p12 \
	ICAM_Test_Card_PIV_OCSP_Revoked_Signer_No_Check_Present_gen3.p12 \
	ICAM_Test_Card_PIV_OCSP_Valid_Signer_gen1-2.p12 \
	ICAM_Test_Card_PIV_OCSP_Valid_Signer_gen3.p12 \
	ICAM_Test_Card_PIV-I_OCSP_Valid_Signer_gen3.p12"

sortbyser() {
	SRC=$1
	DST=/tmp/$(basename $SRC).$$
	sort -t$'\t' -u -k4 $SRC >$DST
	mv $DST $SRC 
}

process() {
	GEN=$1
	shift
	STAT=$1
	shift
	EXP=$1
	shift
	SER=$(expr $1 : "serial=\(.*\)")
	shift
	SUB=$(expr "$*" : "subject= \(.*\)")
	TAB=$(echo -n $'\t')
	if [ r$STAT == r"R" ]; then
		REV=$(date +%y%m%d%H%M%SZ)
	else
		REV=
	fi
	case $GEN in
	piv-gen1-2) 
		DEST=$PIVGEN1_LOCAL ;;
	piv-gen3) 
		DEST=$PIVGEN3_LOCAL ;;
	pivi-gen1-2) 
		DEST=$PIVIGEN1_LOCAL ;;
	pivi-gen3) 
		DEST=$PIVIGEN3_LOCAL ;;
	*)
		echo "Unknown destination: [$GEN]"
		exit 1
	esac
	echo "${STAT}${TAB}${EXP}${TAB}${REV}${TAB}${SER}${TAB}unknown${TAB}${SUB}" >>$DEST
	sortbyser $DEST 
}

p12tocert() {
	openssl pkcs12 \
		-in "$1" \
		-clcerts \
		-passin pass: \
		-nokeys \
		-out "$2" >/dev/null 2>&1
}

p12tokey() {
    openssl pkcs12 \
    	-in $1 \
    	-nocerts \
	    -nodes \
	    -passin pass: \
	    -passout pass: \
	    -out "$2" >/dev/null 2>&1
}

# Re-index the index.txt file

reindex() {

	>$PIVGEN1_LOCAL
	>$PIVGEN3_LOCAL
	>$PIVIGEN1_LOCAL
	>$PIVIGEN3_LOCAL

	pushd ../cards/ICAM_Card_Objects >/dev/null 2>&1
		echo "Creating index for Gen1-2 PIV certs..."
		#for D in 01 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 23 24
		for D in 01 24
		do
			pushd ${D}_* >/dev/null 2>&1
				pwd
				p12tocert '3 - PIV_Auth.p12' '3 - PIV_Auth.crt'
				N="ICAM_Test_Card_${D}_PIV_Auth.crt"
				cp '3 - PIV_Auth.crt' ${CWD}/data/pem/$N
				X=$(openssl x509 -serial -subject -in ${CWD}/data/pem/$N -noout) 
				Y=$(openssl x509 -in ${CWD}/data/pem/$N -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen1-2 $STATUS $Y $X

				p12tocert '4 - PIV_Card_Auth.p12' '4 - PIV_Card_Auth.crt'
				N="ICAM_Test_Card_${D}_PIV_Card_Auth.crt"
				cp '4 - PIV_Card_Auth.crt' ${CWD}/data/pem/$N
				X=$(openssl x509 -serial -subject -in ${CWD}/data/pem/$N -noout) 
				Y=$(openssl x509 -in ${CWD}/data/pem/$N -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen1-2 $STATUS $Y $X
			popd >/dev/null 2>&1
		done

		echo "Creating index for Gen1-2 PIV-I certs (in piv-gen1-2 index)..."
		for D in 02 19 20 21 22
		do
			pushd ${D}_* >/dev/null 2>&1
				pwd
				p12tocert '3 - PIV_Auth.p12' '3 - PIV_Auth.crt'
				N="ICAM_Test_Card_${D}_PIV_Auth.crt"
				cp '3 - PIV_Auth.crt' ${CWD}/data/pem/$N
				X=$(openssl x509 -serial -subject -in ${CWD}/data/pem/$N -noout) 
				Y=$(openssl x509 -in ${CWD}/data/pem/$N -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen1-2 $STATUS $Y $X

				p12tocert '4 - PIV_Card_Auth.p12' '4 - PIV_Card_Auth.crt'
				N="ICAM_Test_Card_${D}_PIV_Auth.crt"
				cp '3 - PIV_Auth.crt' ${CWD}/data/pem/$N
				X=$(openssl x509 -serial -subject -in ${CWD}/data/pem/$N -noout) 
				Y=$(openssl x509 -in ${CWD}/data/pem/$N -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen1-2 $STATUS $Y $X
			popd >/dev/null 2>&1
		done

		echo "Creating index for Gen3 PIV certs..."
		for D in 25 26 27 28 37 38 41 42 43 44 45 46 47 49 50 51 52 53 55 56
		do
			pushd ${D}_* >/dev/null 2>&1
				pwd
				X=$(openssl x509 -serial -subject -in '3 - ICAM_PIV_Auth_SP_800-73-4.crt' -noout) 
				Y=$(openssl x509 -in '3 - ICAM_PIV_Auth_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen3 $STATUS $Y $X

				X=$(openssl x509 -serial -subject -in '4 - ICAM_PIV_Dig_Sig_SP_800-73-4.crt' -noout)
				Y=$(openssl x509 -in '4 - ICAM_PIV_Dig_Sig_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME  | tail -n 1| awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen3 $STATUS $Y $X

				X=$(openssl x509 -serial -subject -in '5 - ICAM_PIV_Key_Mgmt_SP_800-73-4.crt' -noout)
				Y=$(openssl x509 -in '5 - ICAM_PIV_Key_Mgmt_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME  | tail -n 1| awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen3 $STATUS $Y $X

				X=$(openssl x509 -serial -subject -in '6 - ICAM_PIV_Card_Auth_SP_800-73-4.crt' -noout)
				Y=$(openssl x509 -in '6 - ICAM_PIV_Card_Auth_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME  | tail -n 1| awk '{ print $7 }' | sed 's/[:\r]//g')
				if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
				process piv-gen3 $STATUS $Y $X
			popd >/dev/null 2>&1
		done

		echo "Creating index for Gen3 PIV-I certs..."
		for D in 39 54
		do
			pushd ${D}_* >/dev/null 2>&1
				pwd
				X=$(openssl x509 -serial -subject -in '3 - ICAM_PIV_Auth_SP_800-73-4.crt' -noout) 
				Y=$(openssl x509 -in '3 - ICAM_PIV_Auth_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')
				process pivi-gen3 V $Y $X

				X=$(openssl x509 -serial -subject -in '4 - ICAM_PIV_Dig_Sig_SP_800-73-4.crt' -noout)
				Y=$(openssl x509 -in '4 - ICAM_PIV_Dig_Sig_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME  | tail -n 1| awk '{ print $7 }' | sed 's/[:\r]//g')
				process pivi-gen3 V $Y $X

				X=$(openssl x509 -serial -subject -in '5 - ICAM_PIV_Key_Mgmt_SP_800-73-4.crt' -noout)
				Y=$(openssl x509 -in '5 - ICAM_PIV_Key_Mgmt_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME  | tail -n 1| awk '{ print $7 }' | sed 's/[:\r]//g')
				process pivi-gen3 V $Y $X

				X=$(openssl x509 -serial -subject -in '6 - ICAM_PIV_Card_Auth_SP_800-73-4.crt' -noout)
				Y=$(openssl x509 -in '6 - ICAM_PIV_Card_Auth_SP_800-73-4.crt' -outform der | openssl asn1parse -inform der | grep UTCTIME  | tail -n 1| awk '{ print $7 }' | sed 's/[:\r]//g')
				process pivi-gen3 V $Y $X
			popd >/dev/null 2>&1
		done
	popd 

	echo "Adding OCSP response and content signing certs to indices..."
	pushd data >/dev/null 2>&1
		pwd
		CTR=0
		for C in $OCSPCERTS $CONTCERTS
		do
			CTR=$(expr $CTR + 1); if [ $CTR -lt 10 ]; then PAD="0"; else PAD=""; fi

			F=$(basename $C .p12).crt
			if [ ! -f "$F" ]; then p12tocert "$C" "pem/$F"; fi
			K="pem/$(basename $C .p12).private.key"
			if [ ! -f "$K" ]; then p12tokey "$C" "$K"; fi

			X=$(openssl x509 -serial -subject -in "pem/$F" -noout) 
			Y=$(openssl x509 -in "pem/$F" -outform der | openssl asn1parse -inform der | grep UTCTIME | tail -n 1 | awk '{ print $7 }' | sed 's/[:\r]//g')

			if [ $(expr "$F" : ".*Revoked.*$") -ge 7 ]; then STATUS=R; else STATUS=V; fi
			if [ $(expr "$F" : ".*PIV-I.*$") -ge 5 ]; then T=pivi; else T=piv; fi
			if [ $(expr "$F" : ".*gen3.*$") -ge 4 ]; then G=gen3; else G=gen1-2; fi
			# Lump Gen1 PIV-I with PIV
			if [ "${T}-${G}" == "pivi-gen1-2" ]; then
				T="piv"
			fi
			process "$T-$G" $STATUS $Y $X
			echo "${PAD}${CTR}: ${C}..."
		done
	popd >/dev/null 2>&1
}

if [ $# -eq 1 -a r$1 == r"-r" ]; then
	rm -f $PIVGEN1_LOCAL $PIVGEN3_LOCAL $PIVIGEN3_LOCAL
	reindex
fi

# Back it up

/bin/mv $PIVGEN1_DEST $PIVGEN1_DEST.old 2>/dev/null
/bin/mv $PIVGEN3_DEST $PIVGEN3_DEST.old 2>/dev/null
/bin/mv $PIVIGEN1_DEST $PIVIGEN1_DEST.old 2>/dev/null
/bin/mv $PIVIGEN3_DEST $PIVIGEN3_DEST.old 2>/dev/null

# Move into place

cp -p $PIVGEN1_LOCAL $PIVGEN1_DEST
cp -p $PIVGEN3_LOCAL $PIVGEN3_DEST
cp -p $PIVIGEN1_LOCAL $PIVIGEN1_DEST
cp -p $PIVIGEN3_LOCAL $PIVIGEN3_DEST

echo "Revoking known revoked certs..."
## OCSP revoked signer with id-pkix-ocsp-nocheck present using RSA 2048 (RSA 2048 CA)
echo "OCSP revoked signer with id-pkix-ocsp-nocheck present using RSA 2048 (RSA 2048 CA)..."
SUBJ=ICAM_Test_Card_PIV_OCSP_Revoked_Signer_No_Check_Present_gen3 
ISSUER=ICAM_Test_Card_PIV_Signing_CA_-_gold_gen3
CONFIG=${CWD}/icam-piv-ocsp-revoked-nocheck-not-present.cnf
CRL=${CWD}/../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/crls/ICAMTestCardGen3SigningCA.crl
revoke $SUBJ $ISSUER $CONFIG pem $CRL
if [ $? -gt 0 ]; then exit 1; fi
sortbyser $PIVGEN3_LOCAL

## OCSP revoked signer with id-pkix-ocsp-nocheck NOT presetnt using RSA 2048 (RSA 2048 CA)
echo "OCSP revoked signer with id-pkix-ocsp-nocheck NOT presetnt using RSA 2048 (RSA 2048 CA)..."
SUBJ=ICAM_Test_Card_PIV_OCSP_Revoked_Signer_No_Check_Not_Present_gen3 
ISSUER=ICAM_Test_Card_PIV_Signing_CA_-_gold_gen3
CONFIG=${CWD}/icam-piv-ocsp-revoked-nocheck-present.cnf
CRL=${CWD}/../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/crls/ICAMTestCardGen3SigningCA.crl
revoke $SUBJ $ISSUER $CONFIG pem $CRL
if [ $? -gt 0 ]; then exit 1; fi
sortbyser $PIVGEN3_LOCAL

## Gen1-2 Content Signing Cert
echo "Gen1-2 Content Signing Cert..."
SUBJ=ICAM_Test_Card_PIV_Revoked_Content_Signer_gen1-2
ISSUER=ICAM_Test_Card_PIV_Signing_CA_-_gold_gen1-2
CONFIG=${CWD}/icam-piv-revoked-ee-gen1-2.cnf
CRL=${CWD}/../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/crls/ICAMTestCardSigningCA.crl
revoke $SUBJ $ISSUER $CONFIG pem $CRL
if [ $? -gt 0 ]; then exit 1; fi
sortbyser $PIVGEN1_LOCAL

## Gen1-2 Card 24 Revoked PIV Auth 
echo "Gen1-2 Card 24 Revoked PIV Auth..."
SUBJ=ICAM_Test_Card_24_PIV_Auth
ISSUER=ICAM_Test_Card_PIV_Signing_CA_-_gold_gen1-2
CONFIG=${CWD}/icam-piv-revoked-ee-gen1-2.cnf
CRL=${CWD}/../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/crls/ICAMTestCardSigningCA.crl
revoke $SUBJ $ISSUER $CONFIG pem $CRL
if [ $? -gt 0 ]; then exit 1; fi
sortbyser $PIVGEN1_LOCAL

## Gen1-2 Card 24 Revoked PIV Card Auth 
echo "Gen1-2 Card 24 Revoked PIV Card Auth..."
SUBJ=ICAM_Test_Card_24_PIV_Card_Auth
ISSUER=ICAM_Test_Card_PIV_Signing_CA_-_gold_gen1-2
CONFIG=${CWD}/icam-piv-revoked-ee-gen1-2.cnf
CRL=${CWD}/../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/crls/ICAMTestCardSigningCA.crl
revoke $SUBJ $ISSUER $CONFIG pem $CRL
if [ $? -gt 0 ]; then exit 1; fi
sortbyser $PIVGEN1_LOCAL

for F in $PIVGEN1_DEST $PIVGEN3_DEST $PIVIGEN1_DEST $PIVIGEN3_DEST
do
	echo "unique_subject = no" >${F}.attr
	cp -p ${F}.attr .
done

pushd data >/dev/null 2>&1
	pwd
	for F in $SIGNCERTS
	do
		if [ ! -f pem/$F -a -f $(basename $F .crt).p12 ]; then p12tocert $(basename $F .p12) pem/$F; fi
		cp -p pem/$F ..
	done
	for F in $OCSPCERTS
	do
		cp -p $F ..
	done
popd >/dev/null 2>&1

tar cv --owner=root --group=root -f responder-certs.tar \
	$OCSPCERTS \
	$SIGNCERTS \
	$(basename $PIVGEN1_LOCAL) \
	$(basename $PIVGEN3_LOCAL) \
	$(basename $PIVIGEN1_LOCAL) \
	$(basename $PIVIGEN3_LOCAL) \
	$(basename ${PIVGEN1_LOCAL}.attr) \
	$(basename ${PIVGEN3_LOCAL}.attr) \
	$(basename ${PIVIGEN1_LOCAL}.attr) \
	$(basename ${PIVIGEN3_LOCAL}.attr)

rm -f $OCSPCERTS $SIGNCERTS
rm -f $PIVGEN1_LOCAL ${PIVGEN1_LOCAL}.attr
rm -f $PIVGEN3_LOCAL ${PIVGEN3_LOCAL}.attr
rm -f $PIVIGEN1_LOCAL ${PIVIGEN1_LOCAL}.attr
rm -f $PIVIGEN3_LOCAL ${PIVIGEN3_LOCAL}.attr

# AIA, SIA, CRLs

cp -pr ../cards/ICAM_Card_Objects/ICAM_CA_and_Signer/{aia,sia,crls} .

# Backup AIA, CRLs, and SIA
tar cv --owner=root --group=root -f aiacrlsia.tar aia crls sia
rm -rf aia sia crls

mv responder-certs.tar ../responder
mv aiacrlsia.tar ../responder

exit 0