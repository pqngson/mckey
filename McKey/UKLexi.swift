// UKLexi.swift — Stage 1 of the verbatim UniKey engine port.
// Ports vnlexi.h (lexical symbols), the VSeqList / CSeqList / VCPairList spell
// tables and lookups from ukengine.cpp, and the VnLexiName → Unicode mapping.
//
// Enum case names and table ordering mirror the C++ source 1-to-1 so the data
// can be transcribed and indexed exactly as UniKey does (e.g. VSeqList[vs]).

import Foundation

// MARK: - keycons.h

enum UkInputMethod: String { case telex = "Telex", vni = "VNI" }   // (Telex + VNI scope)
enum UkOutputType { case charOutput, keyOutput }

// MARK: - vnlexi.h

enum VnLexiName: Int {
    case vnl_nonVnChar = -1
    case vnl_A = 0, vnl_a, vnl_A1, vnl_a1, vnl_A2, vnl_a2, vnl_A3, vnl_a3, vnl_A4, vnl_a4, vnl_A5, vnl_a5
    case vnl_Ar, vnl_ar, vnl_Ar1, vnl_ar1, vnl_Ar2, vnl_ar2, vnl_Ar3, vnl_ar3, vnl_Ar4, vnl_ar4, vnl_Ar5, vnl_ar5
    case vnl_Ab, vnl_ab, vnl_Ab1, vnl_ab1, vnl_Ab2, vnl_ab2, vnl_Ab3, vnl_ab3, vnl_Ab4, vnl_ab4, vnl_Ab5, vnl_ab5
    case vnl_B, vnl_b, vnl_C, vnl_c
    case vnl_D, vnl_d, vnl_DD, vnl_dd
    case vnl_E, vnl_e, vnl_E1, vnl_e1, vnl_E2, vnl_e2, vnl_E3, vnl_e3, vnl_E4, vnl_e4, vnl_E5, vnl_e5
    case vnl_Er, vnl_er, vnl_Er1, vnl_er1, vnl_Er2, vnl_er2, vnl_Er3, vnl_er3, vnl_Er4, vnl_er4, vnl_Er5, vnl_er5
    case vnl_F, vnl_f, vnl_G, vnl_g, vnl_H, vnl_h
    case vnl_I, vnl_i, vnl_I1, vnl_i1, vnl_I2, vnl_i2, vnl_I3, vnl_i3, vnl_I4, vnl_i4, vnl_I5, vnl_i5
    case vnl_J, vnl_j, vnl_K, vnl_k, vnl_L, vnl_l, vnl_M, vnl_m, vnl_N, vnl_n
    case vnl_O, vnl_o, vnl_O1, vnl_o1, vnl_O2, vnl_o2, vnl_O3, vnl_o3, vnl_O4, vnl_o4, vnl_O5, vnl_o5
    case vnl_Or, vnl_or, vnl_Or1, vnl_or1, vnl_Or2, vnl_or2, vnl_Or3, vnl_or3, vnl_Or4, vnl_or4, vnl_Or5, vnl_or5
    case vnl_Oh, vnl_oh, vnl_Oh1, vnl_oh1, vnl_Oh2, vnl_oh2, vnl_Oh3, vnl_oh3, vnl_Oh4, vnl_oh4, vnl_Oh5, vnl_oh5
    case vnl_P, vnl_p, vnl_Q, vnl_q, vnl_R, vnl_r, vnl_S, vnl_s, vnl_T, vnl_t
    case vnl_U, vnl_u, vnl_U1, vnl_u1, vnl_U2, vnl_u2, vnl_U3, vnl_u3, vnl_U4, vnl_u4, vnl_U5, vnl_u5
    case vnl_Uh, vnl_uh, vnl_Uh1, vnl_uh1, vnl_Uh2, vnl_uh2, vnl_Uh3, vnl_uh3, vnl_Uh4, vnl_uh4, vnl_Uh5, vnl_uh5
    case vnl_V, vnl_v, vnl_W, vnl_w, vnl_X, vnl_x
    case vnl_Y, vnl_y, vnl_Y1, vnl_y1, vnl_Y2, vnl_y2, vnl_Y3, vnl_y3, vnl_Y4, vnl_y4, vnl_Y5, vnl_y5
    case vnl_Z, vnl_z
    case vnl_lastChar
}

enum VowelSeq: Int {
    case vs_nil = -1
    case vs_a = 0, vs_ar, vs_ab, vs_e, vs_er, vs_i, vs_o, vs_or, vs_oh, vs_u, vs_uh, vs_y
    case vs_ai, vs_ao, vs_au, vs_ay, vs_aru, vs_ary, vs_eo, vs_eu, vs_eru
    case vs_ia, vs_ie, vs_ier, vs_iu, vs_oa, vs_oab, vs_oe, vs_oi, vs_ori, vs_ohi
    case vs_ua, vs_uar, vs_ue, vs_uer, vs_ui, vs_uo, vs_uor, vs_uoh, vs_uu, vs_uy
    case vs_uha, vs_uhi, vs_uho, vs_uhoh, vs_uhu, vs_ye, vs_yer, vs_ieu, vs_ieru
    case vs_oai, vs_oay, vs_oeo, vs_uay, vs_uary, vs_uoi, vs_uou, vs_uori, vs_uohi, vs_uohu
    case vs_uya, vs_uye, vs_uyer, vs_uyu, vs_uhoi, vs_uhou, vs_uhohi, vs_uhohu, vs_yeu, vs_yeru
}

enum ConSeq: Int {
    case cs_nil = -1
    case cs_b = 0, cs_c, cs_ch, cs_d, cs_dd, cs_dz, cs_g, cs_gh, cs_gi, cs_gin
    case cs_k, cs_kh, cs_l, cs_m, cs_n, cs_ng, cs_ngh, cs_nh, cs_p, cs_ph
    case cs_q, cs_qu, cs_r, cs_s, cs_t, cs_th, cs_tr, cs_v, cs_x
}

// MARK: - Spell tables (ukengine.cpp)

struct VowelSeqInfo {
    let len: Int, complete: Int, conSuffix: Int
    let v: [VnLexiName]
    let sub: [VowelSeq]
    let roofPos: Int, withRoof: VowelSeq
    let hookPos: Int, withHook: VowelSeq
    init(_ len: Int, _ c: Int, _ cs: Int,
         _ v0: VnLexiName, _ v1: VnLexiName, _ v2: VnLexiName,
         _ s0: VowelSeq, _ s1: VowelSeq, _ s2: VowelSeq,
         _ rp: Int, _ wr: VowelSeq, _ hp: Int, _ wh: VowelSeq) {
        self.len = len; self.complete = c; self.conSuffix = cs
        self.v = [v0, v1, v2]; self.sub = [s0, s1, s2]
        self.roofPos = rp; self.withRoof = wr; self.hookPos = hp; self.withHook = wh
    }
}

let VSeqList: [VowelSeqInfo] = [
    VSI(1,1,1, .vnl_a,.vnl_nonVnChar,.vnl_nonVnChar, .vs_a,.vs_nil,.vs_nil, -1,.vs_ar, -1,.vs_ab),
    VSI(1,1,1, .vnl_ar,.vnl_nonVnChar,.vnl_nonVnChar, .vs_ar,.vs_nil,.vs_nil, 0,.vs_nil, -1,.vs_ab),
    VSI(1,1,1, .vnl_ab,.vnl_nonVnChar,.vnl_nonVnChar, .vs_ab,.vs_nil,.vs_nil, -1,.vs_ar, 0,.vs_nil),
    VSI(1,1,1, .vnl_e,.vnl_nonVnChar,.vnl_nonVnChar, .vs_e,.vs_nil,.vs_nil, -1,.vs_er, -1,.vs_nil),
    VSI(1,1,1, .vnl_er,.vnl_nonVnChar,.vnl_nonVnChar, .vs_er,.vs_nil,.vs_nil, 0,.vs_nil, -1,.vs_nil),
    VSI(1,1,1, .vnl_i,.vnl_nonVnChar,.vnl_nonVnChar, .vs_i,.vs_nil,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(1,1,1, .vnl_o,.vnl_nonVnChar,.vnl_nonVnChar, .vs_o,.vs_nil,.vs_nil, -1,.vs_or, -1,.vs_oh),
    VSI(1,1,1, .vnl_or,.vnl_nonVnChar,.vnl_nonVnChar, .vs_or,.vs_nil,.vs_nil, 0,.vs_nil, -1,.vs_oh),
    VSI(1,1,1, .vnl_oh,.vnl_nonVnChar,.vnl_nonVnChar, .vs_oh,.vs_nil,.vs_nil, -1,.vs_or, 0,.vs_nil),
    VSI(1,1,1, .vnl_u,.vnl_nonVnChar,.vnl_nonVnChar, .vs_u,.vs_nil,.vs_nil, -1,.vs_nil, -1,.vs_uh),
    VSI(1,1,1, .vnl_uh,.vnl_nonVnChar,.vnl_nonVnChar, .vs_uh,.vs_nil,.vs_nil, -1,.vs_nil, 0,.vs_nil),
    VSI(1,1,1, .vnl_y,.vnl_nonVnChar,.vnl_nonVnChar, .vs_y,.vs_nil,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_a,.vnl_i,.vnl_nonVnChar, .vs_a,.vs_ai,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_a,.vnl_o,.vnl_nonVnChar, .vs_a,.vs_ao,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_a,.vnl_u,.vnl_nonVnChar, .vs_a,.vs_au,.vs_nil, -1,.vs_aru, -1,.vs_nil),
    VSI(2,1,0, .vnl_a,.vnl_y,.vnl_nonVnChar, .vs_a,.vs_ay,.vs_nil, -1,.vs_ary, -1,.vs_nil),
    VSI(2,1,0, .vnl_ar,.vnl_u,.vnl_nonVnChar, .vs_ar,.vs_aru,.vs_nil, 0,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_ar,.vnl_y,.vnl_nonVnChar, .vs_ar,.vs_ary,.vs_nil, 0,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_e,.vnl_o,.vnl_nonVnChar, .vs_e,.vs_eo,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,0,0, .vnl_e,.vnl_u,.vnl_nonVnChar, .vs_e,.vs_eu,.vs_nil, -1,.vs_eru, -1,.vs_nil),
    VSI(2,1,0, .vnl_er,.vnl_u,.vnl_nonVnChar, .vs_er,.vs_eru,.vs_nil, 0,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_i,.vnl_a,.vnl_nonVnChar, .vs_i,.vs_ia,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,0,1, .vnl_i,.vnl_e,.vnl_nonVnChar, .vs_i,.vs_ie,.vs_nil, -1,.vs_ier, -1,.vs_nil),
    VSI(2,1,1, .vnl_i,.vnl_er,.vnl_nonVnChar, .vs_i,.vs_ier,.vs_nil, 1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_i,.vnl_u,.vnl_nonVnChar, .vs_i,.vs_iu,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,1,1, .vnl_o,.vnl_a,.vnl_nonVnChar, .vs_o,.vs_oa,.vs_nil, -1,.vs_nil, -1,.vs_oab),
    VSI(2,1,1, .vnl_o,.vnl_ab,.vnl_nonVnChar, .vs_o,.vs_oab,.vs_nil, -1,.vs_nil, 1,.vs_nil),
    VSI(2,1,1, .vnl_o,.vnl_e,.vnl_nonVnChar, .vs_o,.vs_oe,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_o,.vnl_i,.vnl_nonVnChar, .vs_o,.vs_oi,.vs_nil, -1,.vs_ori, -1,.vs_ohi),
    VSI(2,1,0, .vnl_or,.vnl_i,.vnl_nonVnChar, .vs_or,.vs_ori,.vs_nil, 0,.vs_nil, -1,.vs_ohi),
    VSI(2,1,0, .vnl_oh,.vnl_i,.vnl_nonVnChar, .vs_oh,.vs_ohi,.vs_nil, -1,.vs_ori, 0,.vs_nil),
    VSI(2,1,1, .vnl_u,.vnl_a,.vnl_nonVnChar, .vs_u,.vs_ua,.vs_nil, -1,.vs_uar, -1,.vs_uha),
    VSI(2,1,1, .vnl_u,.vnl_ar,.vnl_nonVnChar, .vs_u,.vs_uar,.vs_nil, 1,.vs_nil, -1,.vs_nil),
    VSI(2,0,1, .vnl_u,.vnl_e,.vnl_nonVnChar, .vs_u,.vs_ue,.vs_nil, -1,.vs_uer, -1,.vs_nil),
    VSI(2,1,1, .vnl_u,.vnl_er,.vnl_nonVnChar, .vs_u,.vs_uer,.vs_nil, 1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_u,.vnl_i,.vnl_nonVnChar, .vs_u,.vs_ui,.vs_nil, -1,.vs_nil, -1,.vs_uhi),
    VSI(2,0,1, .vnl_u,.vnl_o,.vnl_nonVnChar, .vs_u,.vs_uo,.vs_nil, -1,.vs_uor, -1,.vs_uho),
    VSI(2,1,1, .vnl_u,.vnl_or,.vnl_nonVnChar, .vs_u,.vs_uor,.vs_nil, 1,.vs_nil, -1,.vs_uoh),
    VSI(2,1,1, .vnl_u,.vnl_oh,.vnl_nonVnChar, .vs_u,.vs_uoh,.vs_nil, -1,.vs_uor, 1,.vs_uhoh),
    VSI(2,0,0, .vnl_u,.vnl_u,.vnl_nonVnChar, .vs_u,.vs_uu,.vs_nil, -1,.vs_nil, -1,.vs_uhu),
    VSI(2,1,1, .vnl_u,.vnl_y,.vnl_nonVnChar, .vs_u,.vs_uy,.vs_nil, -1,.vs_nil, -1,.vs_nil),
    VSI(2,1,0, .vnl_uh,.vnl_a,.vnl_nonVnChar, .vs_uh,.vs_uha,.vs_nil, -1,.vs_nil, 0,.vs_nil),
    VSI(2,1,0, .vnl_uh,.vnl_i,.vnl_nonVnChar, .vs_uh,.vs_uhi,.vs_nil, -1,.vs_nil, 0,.vs_nil),
    VSI(2,0,1, .vnl_uh,.vnl_o,.vnl_nonVnChar, .vs_uh,.vs_uho,.vs_nil, -1,.vs_nil, 0,.vs_uhoh),
    VSI(2,1,1, .vnl_uh,.vnl_oh,.vnl_nonVnChar, .vs_uh,.vs_uhoh,.vs_nil, -1,.vs_nil, 0,.vs_nil),
    VSI(2,1,0, .vnl_uh,.vnl_u,.vnl_nonVnChar, .vs_uh,.vs_uhu,.vs_nil, -1,.vs_nil, 0,.vs_nil),
    VSI(2,0,1, .vnl_y,.vnl_e,.vnl_nonVnChar, .vs_y,.vs_ye,.vs_nil, -1,.vs_yer, -1,.vs_nil),
    VSI(2,1,1, .vnl_y,.vnl_er,.vnl_nonVnChar, .vs_y,.vs_yer,.vs_nil, 1,.vs_nil, -1,.vs_nil),
    VSI(3,0,0, .vnl_i,.vnl_e,.vnl_u, .vs_i,.vs_ie,.vs_ieu, -1,.vs_ieru, -1,.vs_nil),
    VSI(3,1,0, .vnl_i,.vnl_er,.vnl_u, .vs_i,.vs_ier,.vs_ieru, 1,.vs_nil, -1,.vs_nil),
    VSI(3,1,0, .vnl_o,.vnl_a,.vnl_i, .vs_o,.vs_oa,.vs_oai, -1,.vs_nil, -1,.vs_nil),
    VSI(3,1,0, .vnl_o,.vnl_a,.vnl_y, .vs_o,.vs_oa,.vs_oay, -1,.vs_nil, -1,.vs_nil),
    VSI(3,1,0, .vnl_o,.vnl_e,.vnl_o, .vs_o,.vs_oe,.vs_oeo, -1,.vs_nil, -1,.vs_nil),
    VSI(3,0,0, .vnl_u,.vnl_a,.vnl_y, .vs_u,.vs_ua,.vs_uay, -1,.vs_uary, -1,.vs_nil),
    VSI(3,1,0, .vnl_u,.vnl_ar,.vnl_y, .vs_u,.vs_uar,.vs_uary, 1,.vs_nil, -1,.vs_nil),
    VSI(3,0,0, .vnl_u,.vnl_o,.vnl_i, .vs_u,.vs_uo,.vs_uoi, -1,.vs_uori, -1,.vs_uhoi),
    VSI(3,0,0, .vnl_u,.vnl_o,.vnl_u, .vs_u,.vs_uo,.vs_uou, -1,.vs_nil, -1,.vs_uhou),
    VSI(3,1,0, .vnl_u,.vnl_or,.vnl_i, .vs_u,.vs_uor,.vs_uori, 1,.vs_nil, -1,.vs_uohi),
    VSI(3,0,0, .vnl_u,.vnl_oh,.vnl_i, .vs_u,.vs_uoh,.vs_uohi, -1,.vs_uori, 1,.vs_uhohi),
    VSI(3,0,0, .vnl_u,.vnl_oh,.vnl_u, .vs_u,.vs_uoh,.vs_uohu, -1,.vs_nil, 1,.vs_uhohu),
    VSI(3,1,0, .vnl_u,.vnl_y,.vnl_a, .vs_u,.vs_uy,.vs_uya, -1,.vs_nil, -1,.vs_nil),
    VSI(3,0,1, .vnl_u,.vnl_y,.vnl_e, .vs_u,.vs_uy,.vs_uye, -1,.vs_uyer, -1,.vs_nil),
    VSI(3,1,1, .vnl_u,.vnl_y,.vnl_er, .vs_u,.vs_uy,.vs_uyer, 2,.vs_nil, -1,.vs_nil),
    VSI(3,1,0, .vnl_u,.vnl_y,.vnl_u, .vs_u,.vs_uy,.vs_uyu, -1,.vs_nil, -1,.vs_nil),
    VSI(3,0,0, .vnl_uh,.vnl_o,.vnl_i, .vs_uh,.vs_uho,.vs_uhoi, -1,.vs_nil, 0,.vs_uhohi),
    VSI(3,0,0, .vnl_uh,.vnl_o,.vnl_u, .vs_uh,.vs_uho,.vs_uhou, -1,.vs_nil, 0,.vs_uhohu),
    VSI(3,1,0, .vnl_uh,.vnl_oh,.vnl_i, .vs_uh,.vs_uhoh,.vs_uhohi, -1,.vs_nil, 0,.vs_nil),
    VSI(3,1,0, .vnl_uh,.vnl_oh,.vnl_u, .vs_uh,.vs_uhoh,.vs_uhohu, -1,.vs_nil, 0,.vs_nil),
    VSI(3,0,0, .vnl_y,.vnl_e,.vnl_u, .vs_y,.vs_ye,.vs_yeu, -1,.vs_yeru, -1,.vs_nil),
    VSI(3,1,0, .vnl_y,.vnl_er,.vnl_u, .vs_y,.vs_yer,.vs_yeru, 1,.vs_nil, -1,.vs_nil),
]

private func VSI(_ len: Int, _ c: Int, _ cs: Int,
                 _ v0: VnLexiName, _ v1: VnLexiName, _ v2: VnLexiName,
                 _ s0: VowelSeq, _ s1: VowelSeq, _ s2: VowelSeq,
                 _ rp: Int, _ wr: VowelSeq, _ hp: Int, _ wh: VowelSeq) -> VowelSeqInfo {
    VowelSeqInfo(len, c, cs, v0, v1, v2, s0, s1, s2, rp, wr, hp, wh)
}

struct ConSeqInfo {
    let len: Int
    let c: [VnLexiName]
    let suffix: Bool
    init(_ len: Int, _ c0: VnLexiName, _ c1: VnLexiName, _ c2: VnLexiName, _ suffix: Bool) {
        self.len = len; self.c = [c0, c1, c2]; self.suffix = suffix
    }
}

let CSeqList: [ConSeqInfo] = [
    ConSeqInfo(1, .vnl_b,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_c,.vnl_nonVnChar,.vnl_nonVnChar, true),
    ConSeqInfo(2, .vnl_c,.vnl_h,.vnl_nonVnChar, true),
    ConSeqInfo(1, .vnl_d,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_dd,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(2, .vnl_d,.vnl_z,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_g,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(2, .vnl_g,.vnl_h,.vnl_nonVnChar, false),
    ConSeqInfo(2, .vnl_g,.vnl_i,.vnl_nonVnChar, false),
    ConSeqInfo(3, .vnl_g,.vnl_i,.vnl_n, false),
    ConSeqInfo(1, .vnl_k,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(2, .vnl_k,.vnl_h,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_l,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_m,.vnl_nonVnChar,.vnl_nonVnChar, true),
    ConSeqInfo(1, .vnl_n,.vnl_nonVnChar,.vnl_nonVnChar, true),
    ConSeqInfo(2, .vnl_n,.vnl_g,.vnl_nonVnChar, true),
    ConSeqInfo(3, .vnl_n,.vnl_g,.vnl_h, false),
    ConSeqInfo(2, .vnl_n,.vnl_h,.vnl_nonVnChar, true),
    ConSeqInfo(1, .vnl_p,.vnl_nonVnChar,.vnl_nonVnChar, true),
    ConSeqInfo(2, .vnl_p,.vnl_h,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_q,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(2, .vnl_q,.vnl_u,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_r,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_s,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_t,.vnl_nonVnChar,.vnl_nonVnChar, true),
    ConSeqInfo(2, .vnl_t,.vnl_h,.vnl_nonVnChar, false),
    ConSeqInfo(2, .vnl_t,.vnl_r,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_v,.vnl_nonVnChar,.vnl_nonVnChar, false),
    ConSeqInfo(1, .vnl_x,.vnl_nonVnChar,.vnl_nonVnChar, false),
]

// Legal vowel-seq + final-consonant pairs (VCPairList).
let VCPairList: Set<Int> = {
    let pairs: [(VowelSeq, ConSeq)] = [
        (.vs_a,.cs_c),(.vs_a,.cs_ch),(.vs_a,.cs_m),(.vs_a,.cs_n),(.vs_a,.cs_ng),(.vs_a,.cs_nh),(.vs_a,.cs_p),(.vs_a,.cs_t),
        (.vs_ar,.cs_c),(.vs_ar,.cs_m),(.vs_ar,.cs_n),(.vs_ar,.cs_ng),(.vs_ar,.cs_p),(.vs_ar,.cs_t),
        (.vs_ab,.cs_c),(.vs_ab,.cs_m),(.vs_ab,.cs_n),(.vs_ab,.cs_ng),(.vs_ab,.cs_p),(.vs_ab,.cs_t),
        (.vs_e,.cs_c),(.vs_e,.cs_ch),(.vs_e,.cs_m),(.vs_e,.cs_n),(.vs_e,.cs_ng),(.vs_e,.cs_nh),(.vs_e,.cs_p),(.vs_e,.cs_t),
        (.vs_er,.cs_c),(.vs_er,.cs_ch),(.vs_er,.cs_m),(.vs_er,.cs_n),(.vs_er,.cs_nh),(.vs_er,.cs_p),(.vs_er,.cs_t),
        (.vs_i,.cs_c),(.vs_i,.cs_ch),(.vs_i,.cs_m),(.vs_i,.cs_n),(.vs_i,.cs_nh),(.vs_i,.cs_p),(.vs_i,.cs_t),
        (.vs_o,.cs_c),(.vs_o,.cs_m),(.vs_o,.cs_n),(.vs_o,.cs_ng),(.vs_o,.cs_p),(.vs_o,.cs_t),
        (.vs_or,.cs_c),(.vs_or,.cs_m),(.vs_or,.cs_n),(.vs_or,.cs_ng),(.vs_or,.cs_p),(.vs_or,.cs_t),
        (.vs_oh,.cs_m),(.vs_oh,.cs_n),(.vs_oh,.cs_p),(.vs_oh,.cs_t),
        (.vs_u,.cs_c),(.vs_u,.cs_m),(.vs_u,.cs_n),(.vs_u,.cs_ng),(.vs_u,.cs_p),(.vs_u,.cs_t),
        (.vs_uh,.cs_c),(.vs_uh,.cs_m),(.vs_uh,.cs_n),(.vs_uh,.cs_ng),(.vs_uh,.cs_t),
        (.vs_y,.cs_t),
        (.vs_ie,.cs_c),(.vs_ie,.cs_m),(.vs_ie,.cs_n),(.vs_ie,.cs_ng),(.vs_ie,.cs_p),(.vs_ie,.cs_t),
        (.vs_ier,.cs_c),(.vs_ier,.cs_m),(.vs_ier,.cs_n),(.vs_ier,.cs_ng),(.vs_ier,.cs_p),(.vs_ier,.cs_t),
        (.vs_oa,.cs_c),(.vs_oa,.cs_ch),(.vs_oa,.cs_m),(.vs_oa,.cs_n),(.vs_oa,.cs_ng),(.vs_oa,.cs_nh),(.vs_oa,.cs_p),(.vs_oa,.cs_t),
        (.vs_oab,.cs_c),(.vs_oab,.cs_m),(.vs_oab,.cs_n),(.vs_oab,.cs_ng),(.vs_oab,.cs_t),
        (.vs_oe,.cs_n),(.vs_oe,.cs_t),
        (.vs_ua,.cs_n),(.vs_ua,.cs_ng),(.vs_ua,.cs_t),
        (.vs_uar,.cs_n),(.vs_uar,.cs_ng),(.vs_uar,.cs_t),
        (.vs_ue,.cs_c),(.vs_ue,.cs_ch),(.vs_ue,.cs_n),(.vs_ue,.cs_nh),
        (.vs_uer,.cs_c),(.vs_uer,.cs_ch),(.vs_uer,.cs_n),(.vs_uer,.cs_nh),
        (.vs_uo,.cs_c),(.vs_uo,.cs_m),(.vs_uo,.cs_n),(.vs_uo,.cs_ng),(.vs_uo,.cs_p),(.vs_uo,.cs_t),
        (.vs_uor,.cs_c),(.vs_uor,.cs_m),(.vs_uor,.cs_n),(.vs_uor,.cs_ng),(.vs_uor,.cs_t),
        (.vs_uho,.cs_c),(.vs_uho,.cs_m),(.vs_uho,.cs_n),(.vs_uho,.cs_ng),(.vs_uho,.cs_p),(.vs_uho,.cs_t),
        (.vs_uhoh,.cs_c),(.vs_uhoh,.cs_m),(.vs_uhoh,.cs_n),(.vs_uhoh,.cs_ng),(.vs_uhoh,.cs_p),(.vs_uhoh,.cs_t),
        (.vs_uy,.cs_c),(.vs_uy,.cs_ch),(.vs_uy,.cs_n),(.vs_uy,.cs_nh),(.vs_uy,.cs_p),(.vs_uy,.cs_t),
        (.vs_ye,.cs_m),(.vs_ye,.cs_n),(.vs_ye,.cs_ng),(.vs_ye,.cs_p),(.vs_ye,.cs_t),
        (.vs_yer,.cs_m),(.vs_yer,.cs_n),(.vs_yer,.cs_ng),(.vs_yer,.cs_t),
        (.vs_uye,.cs_n),(.vs_uye,.cs_t),
        (.vs_uyer,.cs_n),(.vs_uyer,.cs_t),
    ]
    var s = Set<Int>()
    for (v, c) in pairs { s.insert(v.rawValue * 1000 + c.rawValue) }
    return s
}()

func validVC(_ v: VowelSeq, _ c: ConSeq) -> Bool {
    VCPairList.contains(v.rawValue * 1000 + c.rawValue)
}

// MARK: - Lookups (replace UniKey's sorted bsearch with dictionaries)

private func tripleKey(_ a: VnLexiName, _ b: VnLexiName, _ c: VnLexiName) -> Int {
    (a.rawValue + 1) * 1_000_000 + (b.rawValue + 1) * 1000 + (c.rawValue + 1)
}

private let vseqLookup: [Int: VowelSeq] = {
    var d = [Int: VowelSeq]()
    for (i, info) in VSeqList.enumerated() {
        d[tripleKey(info.v[0], info.v[1], info.v[2])] = VowelSeq(rawValue: i)!
    }
    return d
}()

private let cseqLookup: [Int: ConSeq] = {
    var d = [Int: ConSeq]()
    for (i, info) in CSeqList.enumerated() {
        let key: Int
        if info.len == 1 { key = tripleKey(info.c[0], .vnl_nonVnChar, .vnl_nonVnChar) }
        else if info.len == 2 { key = tripleKey(info.c[0], info.c[1], .vnl_nonVnChar) }
        else { key = tripleKey(info.c[0], info.c[1], info.c[2]) }
        d[key] = ConSeq(rawValue: i)!
    }
    return d
}()

func lookupVSeq(_ v1: VnLexiName, _ v2: VnLexiName = .vnl_nonVnChar, _ v3: VnLexiName = .vnl_nonVnChar) -> VowelSeq {
    vseqLookup[tripleKey(v1, v2, v3)] ?? .vs_nil
}

func lookupCSeq(_ c1: VnLexiName, _ c2: VnLexiName = .vnl_nonVnChar, _ c3: VnLexiName = .vnl_nonVnChar) -> ConSeq {
    cseqLookup[tripleKey(c1, c2, c3)] ?? .cs_nil
}

// MARK: - Vowel classification + Unicode mapping

/// One "vowel family": a base glyph (with its mark) and the 12 enum cases
/// (6 tones × upper/lower) that follow its starting symbol.
private struct VowelFamily { let start: VnLexiName; let upper: String; let lower: String }
private let vowelFamilies: [VowelFamily] = [
    .init(start: .vnl_A,  upper: "A", lower: "a"),
    .init(start: .vnl_Ar, upper: "Â", lower: "â"),
    .init(start: .vnl_Ab, upper: "Ă", lower: "ă"),
    .init(start: .vnl_E,  upper: "E", lower: "e"),
    .init(start: .vnl_Er, upper: "Ê", lower: "ê"),
    .init(start: .vnl_I,  upper: "I", lower: "i"),
    .init(start: .vnl_O,  upper: "O", lower: "o"),
    .init(start: .vnl_Or, upper: "Ô", lower: "ô"),
    .init(start: .vnl_Oh, upper: "Ơ", lower: "ơ"),
    .init(start: .vnl_U,  upper: "U", lower: "u"),
    .init(start: .vnl_Uh, upper: "Ư", lower: "ư"),
    .init(start: .vnl_Y,  upper: "Y", lower: "y"),
]
private let combiningTone = ["", "\u{0301}", "\u{0300}", "\u{0309}", "\u{0303}", "\u{0323}"]

private let consonantGlyph: [VnLexiName: String] = [
    .vnl_B: "B", .vnl_b: "b", .vnl_C: "C", .vnl_c: "c", .vnl_D: "D", .vnl_d: "d",
    .vnl_DD: "Đ", .vnl_dd: "đ", .vnl_F: "F", .vnl_f: "f", .vnl_G: "G", .vnl_g: "g",
    .vnl_H: "H", .vnl_h: "h", .vnl_J: "J", .vnl_j: "j", .vnl_K: "K", .vnl_k: "k",
    .vnl_L: "L", .vnl_l: "l", .vnl_M: "M", .vnl_m: "m", .vnl_N: "N", .vnl_n: "n",
    .vnl_P: "P", .vnl_p: "p", .vnl_Q: "Q", .vnl_q: "q", .vnl_R: "R", .vnl_r: "r",
    .vnl_S: "S", .vnl_s: "s", .vnl_T: "T", .vnl_t: "t", .vnl_V: "V", .vnl_v: "v",
    .vnl_W: "W", .vnl_w: "w", .vnl_X: "X", .vnl_x: "x", .vnl_Z: "Z", .vnl_z: "z",
]

/// VnLexiName → Unicode string, and which symbols are vowels.
let (vnLexiUnicode, isVnVowelSym): ([Int: String], Set<Int>) = {
    var map = [Int: String]()
    var vowels = Set<Int>()
    for fam in vowelFamilies {
        for tone in 0..<6 {
            for (caseIdx, glyph) in [(0, fam.upper), (1, fam.lower)] {
                let raw = fam.start.rawValue + tone * 2 + caseIdx
                let s = (glyph + combiningTone[tone]).precomposedStringWithCanonicalMapping
                map[raw] = s
                vowels.insert(raw)
            }
        }
    }
    for (sym, g) in consonantGlyph { map[sym.rawValue] = g }
    return (map, vowels)
}()

func unicodeFor(_ sym: VnLexiName) -> String { vnLexiUnicode[sym.rawValue] ?? "" }
func isVnVowel(_ sym: VnLexiName) -> Bool { isVnVowelSym.contains(sym.rawValue) }

// MARK: - Engine helper tables (StdVnNoTone, StdVnRootChar, case)

// The enum layout keeps even raw = uppercase, odd = lowercase throughout, so
// case toggling is pure arithmetic (matches ukengine.cpp changeCase/vnToLower).
func changeCase(_ x: VnLexiName) -> VnLexiName {
    if x == .vnl_nonVnChar { return x }
    return VnLexiName(rawValue: (x.rawValue & 1) == 0 ? x.rawValue + 1 : x.rawValue - 1)!
}
func vnToLower(_ x: VnLexiName) -> VnLexiName {
    if x == .vnl_nonVnChar { return x }
    return (x.rawValue & 1) == 0 ? VnLexiName(rawValue: x.rawValue + 1)! : x
}

// StdVnNoTone[sym]: lowercase, tone removed (mark kept). Identity for non-vowels.
// StdVnRootChar[sym]: base letter, mark + tone removed (for last-word checks).
private let baseLowerOfFamily: [VnLexiName: VnLexiName] = [
    .vnl_A: .vnl_a, .vnl_Ar: .vnl_a, .vnl_Ab: .vnl_a, .vnl_E: .vnl_e, .vnl_Er: .vnl_e,
    .vnl_I: .vnl_i, .vnl_O: .vnl_o, .vnl_Or: .vnl_o, .vnl_Oh: .vnl_o, .vnl_U: .vnl_u,
    .vnl_Uh: .vnl_u, .vnl_Y: .vnl_y,
]

let (stdVnNoToneTable, stdVnRootTable): ([VnLexiName], [VnLexiName]) = {
    let n = VnLexiName.vnl_lastChar.rawValue
    var noTone = (0..<n).map { VnLexiName(rawValue: $0)! }
    var root = noTone
    for fam in vowelFamilies {
        let lowerNoTone = VnLexiName(rawValue: fam.start.rawValue + 1)!   // odd = lowercase, tone 0
        let rootLower = baseLowerOfFamily[fam.start]!
        for off in 0..<12 {
            let raw = fam.start.rawValue + off
            noTone[raw] = lowerNoTone
            root[raw] = rootLower
        }
    }
    root[VnLexiName.vnl_DD.rawValue] = .vnl_d
    root[VnLexiName.vnl_dd.rawValue] = .vnl_d
    return (noTone, root)
}()

func stdVnNoTone(_ s: VnLexiName) -> VnLexiName {
    s == .vnl_nonVnChar ? s : stdVnNoToneTable[s.rawValue]
}
func stdVnRootChar(_ s: VnLexiName) -> VnLexiName {
    s == .vnl_nonVnChar ? s : stdVnRootTable[s.rawValue]
}

/// Final Unicode for a stored (vnSym canonical-lowercase, tone, caps) triple.
func renderSymbol(_ vnSym: VnLexiName, tone: Int, caps: Bool) -> String {
    if vnSym == .vnl_nonVnChar { return "" }
    var raw = vnSym.rawValue + tone * 2   // tone variants are +2 each in the enum
    if caps { raw -= 1 }                  // even raw = uppercase
    return vnLexiUnicode[raw] ?? ""
}
