import { useAuth } from "./AuthContext";

export type { AppUser as MemberUser } from "./AuthContext";

export const useMemberAuth = useAuth;

export const MemberAuthProvider = () => null;
