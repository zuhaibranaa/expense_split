import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  region: 'europe-west1',
  maxInstances: 10,
  memory: '256MiB',
  timeoutSeconds: 60,
});

export { bootstrapUser, syncMemberProfile } from './auth';
export {
  createInvite,
  claimInvite,
  deleteGroup,
  onGroupCreated,
  removeMember,
  resetPersonalBalance,
} from './groups';
export { onExpenseCreated } from './expenses';
export { onDeviceRegistered, onDeviceRemoved } from './devices';
export {
  sendSettlementReminder,
  sendTestNotification,
} from './notifications';
export { cleanupInvites, onUserDelete } from './cleanup';
