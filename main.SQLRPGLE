**free
// %CSTD===========================================================*
// %ECSTD==========================================================*
//
 //*********************************************************//
 //          Définition des fichiers                        //
 //*********************************************************//
Dcl-f effectif disk keyed usage(*input) prefix(eff_);

//**********************************************************//
//              Définition des variables                    //
//**********************************************************//
dcl-s w_matricule like(eff_matricule);
dcl-s w_cest_qui  like(ps_cest_qui);
dcl-s w_controle_ok ind inz;
dcl-s w_type_acces like(pe_type_acces);
dcl-s w_type_ok ind inz;
dcl-s w_matricule_ok ind inz;
dcl-s wsql_matricule like (eff_matricule);
dcl-s wsql_nom like (eff_nom);
dcl-s wsql_prenom like (eff_prenom);
dcl-s w_trouve ind inz;
dcl-s w_code_retour char(2);

//**********************************************************//
//        Définition des zones clés                         //
//**********************************************************//
dcl-s K_Eff_Matricule like(eff_matricule);

//**********************************************************//
//        Définition des paramètres d'appel des pgms        //
//**********************************************************//
dcl-s ctlmat_matr zoned(4:0);
dcl-s ctlmat_retour char(2);

//**********************************************************//
//              Définition des constantes                   //
//**********************************************************//
dcl-c w_inconnu Const('Inconnu(e)');

//**********************************************************//
//              Définition des prototypes                   //
//**********************************************************//
  // Prototype du programme CTLMAT
dcl-pr Controle_du_Matricule extpgm('CTLMAT');
   *n zoned(4:0); // Code matricule  => ctlmat_matr
   *n char(2);    // code retour     => ctlmat_retour
end-pr;

//**********************************************************//
//         Déclaration des paramètres du programme          //
//**********************************************************//
dcl-pi *n;
  // Entrée
  pe_matricule like(eff_matricule) const;
  pe_type_acces char(3) const;
  ps_cest_qui char(36);
  ps_code_retour char(2);
  ps_retour_ok ind;
end-pi;

//**********************************************************//
//                  Début du programme                      //
//**********************************************************//
// Initialisations
 ExSr initialise;

// Contrôles
 ExSr controles;

// Si les contrôles sont OK, on peut traiter
  If w_controle_ok;
     ExSr traitement;
  EndIf;

// Conclusion
 ExSr sortie_pgm;

//**********************************************************//
//                  Initialisations                         //
//**********************************************************//
 BegSr initialise;

// Valorise les données internes au programme
 w_matricule = pe_matricule;
 w_type_acces = %UPPER(pe_type_acces);
 w_cest_qui  = *Blanks;
 w_code_retour  = '99';
 w_trouve = *Off;
 w_controle_ok = *Off;  // (je peux supposer que ça va mal se passer)
 w_type_ok = *On;       // (j'ai le droit de penser que ça va bien se passer)

// Neutralise les données de sortie (avant de savoir si ça va bien se passer)
 Clear ps_cest_qui;
 ps_code_retour = '00';
 ReSet ps_retour_ok;

 EndSr;


//**********************************************************//
//                  Contrôles                               //
//**********************************************************//
 BegSr controles;

// contrôle du paramètre type d'accès
 If w_type_acces <> 'SQL' And w_type_acces <> 'NAT' ;
    w_type_ok = *Off;
 EndIf;

 // On peut choisir d'arrêter ici l'aventure
 If Not w_type_ok;
    w_controle_ok = *Off;
    LeaveSR;
 EndIf;

// controle du matricule
 ExSr controle_matricule;
 w_matricule_ok = ctlmat_retour = 'OK';

// Tout est bon ?
 w_controle_ok = (w_type_ok and w_matricule_ok);

 EndSr;

//**********************************************************//
//        Contrôles du matricule (pgm externe)              //
//**********************************************************//
 BegSr controle_matricule;

 // prépare paramètres d'appel
  ctlmat_matr = w_matricule;
  clear ctlmat_retour;

  controle_du_matricule(ctlmat_matr:
                        ctlmat_retour);

 EndSr;

//**********************************************************//
//                  Traitement spécifique                   //
//**********************************************************//
 BegSr traitement;

  Select;

  // Accès par SQL
    When w_type_acces = 'SQL';
      ExSr Acces_SQL;

  // Accès avec instruction natives DB2
    When w_type_acces = 'NAT';
      ExSr Acces_NAT;

  // Pas prévu !! => gérer   (normalement on n'arrive pas jusque là)
    Other;
      w_code_retour = '99';

  EndSl;

 EndSr;

//**********************************************************//
//                  Accès EFFECTIF par SQL                  //
//**********************************************************//
 BegSr Acces_SQL;

 // Valorise variables de l'instruction
  wsql_matricule = w_matricule;

  Exec SQL
    Select prenom, nom
     Into :wsql_prenom, :wsql_nom
     From EFFECTIF
     Where matricule = :wsql_matricule;

  // tu trouves ou pas ?
  Select;
   When SQLCODE = 0;
      w_cest_qui = %Trim(wsql_prenom) + ' ' + %Trim(wsql_nom);
      w_code_retour = '00';

   When SQLCODE = 100;
      w_code_retour = '01';

   Other;
      w_code_retour = '02';

  EndSl;

  // dit que ça s'est bien passé
  w_trouve = SQLCODE = 0;

 EndSr;

//**********************************************************//
//                  Accès EFFECTIF natif DB2                //
//**********************************************************//
 BegSr Acces_NAT;

 // valorise les clés d'accès
  K_Eff_Matricule = w_matricule;

  Chain K_Eff_Matricule EFFECTIF;

 // tu trouves ou pas ?
  If not %Found(EFFECTIF);
     w_code_retour = '01';
   Else;
     w_trouve = *On;
     w_cest_qui = %Trim(eff_prenom) + ' ' + %Trim(eff_nom);
     w_code_retour = '00';
  EndIf;

 EndSr;

//**********************************************************//
//                  Eteint la lmumière en partant           //
//**********************************************************//
 BegSr sortie_pgm;

 // Données de sortie
  ps_code_retour = w_code_retour;
  ps_retour_ok = (w_controle_ok And w_trouve);

  // spécifique selon déroulement des opérations
  If w_trouve ;
     ps_cest_qui = w_cest_qui;
   Else;
     ps_cest_qui = w_inconnu;
  EndIf;

  Return;
 EndSr; 
